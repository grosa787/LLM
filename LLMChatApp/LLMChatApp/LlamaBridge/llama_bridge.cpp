#include "llama_bridge.h"

#include <mutex>
#include <optional>
#include <string>

// Include llama.cpp headers
#include "llama.h"

namespace {
std::mutex g_mutex;
std::optional<std::string> g_last_response;
bool g_cancel_requested = false;
}

llama_context_ref llama_create_context_from_model_path(const char* model_path) {
    std::lock_guard<std::mutex> lock(g_mutex);
    auto params = llama_context_default_params();
    auto model = llama_load_model_from_file(model_path, params);
    if (!model) {
        return nullptr;
    }
    auto ctx_params = llama_context_default_params();
    return llama_new_context_with_model(model, ctx_params);
}

void llama_free_context(llama_context_ref context) {
    if (!context) {
        return;
    }
    auto ctx = static_cast<llama_context*>(context);
    auto model = llama_get_model(ctx);
    llama_free(ctx);
    llama_free_model(model);
}

const char* llama_generate_response(llama_context_ref context, const char* prompt, double temperature, int max_tokens) {
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        g_cancel_requested = false;
        g_last_response.emplace();
        g_last_response->clear();
    }

    auto ctx = static_cast<llama_context*>(context);

    llama_batch batch = llama_batch_init(512, 0, 1);
    llama_token prompt_tokens[4096];
    const int n_tokens = llama_tokenize(llama_get_model(ctx), prompt, prompt_tokens, 4096, true, false);

    for (int i = 0; i < n_tokens; ++i) {
        batch.token[i] = prompt_tokens[i];
        batch.n_tokens++; // For inference
    }

    llama_sampling_params sparams = llama_sampling_default_params();
    sparams.temp = temperature;
    sparams.top_k = 40;
    sparams.top_p = 0.95f;

    llama_kv_cache_seq rm = {0, 0, LLAMA_KV_CACHE_FREE_ALL};
    llama_kv_cache_update(ctx, rm);

    for (int i = 0; i < max_tokens; ++i) {
        {
            std::lock_guard<std::mutex> lock(g_mutex);
            if (g_cancel_requested) {
                break;
            }
        }
        llama_decode(ctx, batch);

        const llama_token token = llama_sampling_sample(ctx, nullptr, sparams);
        if (token == llama_token_eos(llama_get_model(ctx))) {
            break;
        }

        const char* token_text = llama_token_to_str(ctx, token);
        if (token_text) {
            std::lock_guard<std::mutex> lock(g_mutex);
            *g_last_response += token_text;
        }

        batch.token[0] = token;
        batch.n_tokens = 1;
    }

    llama_batch_free(batch);

    std::lock_guard<std::mutex> lock(g_mutex);
    return g_last_response ? g_last_response->c_str() : "";
}

void llama_cancel(void) {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_cancel_requested = true;
}
