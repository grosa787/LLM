#include "llama_bridge.h"

#include <atomic>
#include <cstring>
#include <mutex>
#include <new>
#include <optional>
#include <string>
#include <vector>

// Include llama.cpp headers
#include "llama.h"

namespace {
struct LlamaContextWrapper {
    llama_model * model = nullptr;
    llama_context * context = nullptr;
};

std::mutex g_mutex;
std::optional<std::string> g_last_response;
bool g_cancel_requested = false;
std::atomic<int> g_active_contexts{0};

LlamaContextWrapper * unwrap_context(llama_context_ref ref) {
    return static_cast<LlamaContextWrapper *>(ref);
}
} // namespace

llama_context_ref llama_create_context_from_model_path(const char * model_path) {
    if (model_path == nullptr || std::strlen(model_path) == 0) {
        return nullptr;
    }

    std::lock_guard<std::mutex> lock(g_mutex);

    if (g_active_contexts.load(std::memory_order_relaxed) == 0) {
        llama_backend_init();
    }

    llama_model_params model_params = llama_model_default_params();
    llama_model * model = llama_model_load_from_file(model_path, model_params);
    if (model == nullptr) {
        if (g_active_contexts.load(std::memory_order_relaxed) == 0) {
            llama_backend_free();
        }
        return nullptr;
    }

    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = 4096;
    ctx_params.n_batch = 512;
    llama_context * context = llama_init_from_model(model, ctx_params);
    if (context == nullptr) {
        llama_model_free(model);
        if (g_active_contexts.load(std::memory_order_relaxed) == 0) {
            llama_backend_free();
        }
        return nullptr;
    }

    auto * wrapper = new (std::nothrow) LlamaContextWrapper();
    if (wrapper == nullptr) {
        llama_free(context);
        llama_model_free(model);
        if (g_active_contexts.load(std::memory_order_relaxed) == 0) {
            llama_backend_free();
        }
        return nullptr;
    }

    wrapper->model = model;
    wrapper->context = context;

    g_active_contexts.fetch_add(1, std::memory_order_relaxed);
    return wrapper;
}

void llama_free_context(llama_context_ref context) {
    if (context == nullptr) {
        return;
    }

    std::lock_guard<std::mutex> lock(g_mutex);
    auto * wrapper = unwrap_context(context);

    if (wrapper->context != nullptr) {
        llama_free(wrapper->context);
        wrapper->context = nullptr;
    }
    if (wrapper->model != nullptr) {
        llama_model_free(wrapper->model);
        wrapper->model = nullptr;
    }

    delete wrapper;

    if (g_active_contexts.fetch_sub(1, std::memory_order_relaxed) == 1) {
        llama_backend_free();
    }
}

const char * llama_generate_response(llama_context_ref context, const char * prompt, double temperature, int max_tokens) {
    auto * wrapper = unwrap_context(context);
    if (wrapper == nullptr || wrapper->context == nullptr || wrapper->model == nullptr || prompt == nullptr) {
        return nullptr;
    }

    {
        std::lock_guard<std::mutex> lock(g_mutex);
        g_cancel_requested = false;
        g_last_response.emplace();
        g_last_response->clear();
    }

    auto * ctx = wrapper->context;
    auto * model = wrapper->model;
    const llama_vocab * vocab = llama_model_get_vocab(model);
    if (vocab == nullptr) {
        return nullptr;
    }

    const size_t prompt_length = std::strlen(prompt);
    const int32_t n_prompt = -llama_tokenize(vocab, prompt, prompt_length, nullptr, 0, true, true);
    if (n_prompt <= 0) {
        return nullptr;
    }

    std::vector<llama_token> prompt_tokens(static_cast<size_t>(n_prompt));
    if (llama_tokenize(vocab, prompt, prompt_length, prompt_tokens.data(), prompt_tokens.size(), true, true) < 0) {
        return nullptr;
    }

    llama_batch batch = llama_batch_get_one(prompt_tokens.data(), prompt_tokens.size());
    if (batch.n_tokens > 0) {
        batch.logits[batch.n_tokens - 1] = true;
    }

    if (llama_model_has_encoder(model)) {
        if (llama_encode(ctx, batch) != 0) {
            llama_batch_free(batch);
            return nullptr;
        }

        llama_token decoder_start_token_id = llama_model_decoder_start_token(model);
        if (decoder_start_token_id == LLAMA_TOKEN_NULL) {
            decoder_start_token_id = llama_vocab_bos(vocab);
        }

        llama_batch_free(batch);
        batch = llama_batch_get_one(&decoder_start_token_id, 1);
        batch.logits[0] = true;
    }

    auto sampler_params = llama_sampler_chain_default_params();
    llama_sampler * sampler = llama_sampler_chain_init(sampler_params);
    if (sampler == nullptr) {
        llama_batch_free(batch);
        return nullptr;
    }

    auto add_sampler = [sampler](llama_sampler * node) {
        if (node == nullptr) {
            return false;
        }
        llama_sampler_chain_add(sampler, node);
        return true;
    };

    if (temperature <= 0.0) {
        if (!add_sampler(llama_sampler_init_greedy())) {
            llama_sampler_free(sampler);
            llama_batch_free(batch);
            return nullptr;
        }
    } else {
        const uint32_t seed = static_cast<uint32_t>(llama_time_us());
        if (!add_sampler(llama_sampler_init_top_k(40)) ||
            !add_sampler(llama_sampler_init_top_p(0.95f, 1)) ||
            !add_sampler(llama_sampler_init_temp(static_cast<float>(temperature))) ||
            !add_sampler(llama_sampler_init_dist(seed))) {
            llama_sampler_free(sampler);
            llama_batch_free(batch);
            return nullptr;
        }
    }

    int generated = 0;
    while (generated < max_tokens) {
        {
            std::lock_guard<std::mutex> lock(g_mutex);
            if (g_cancel_requested) {
                break;
            }
        }

        if (llama_decode(ctx, batch) != 0) {
            break;
        }

        llama_token token_id = llama_sampler_sample(sampler, ctx, -1);
        if (llama_vocab_is_eog(vocab, token_id)) {
            break;
        }

        char piece[256];
        const int32_t piece_length = llama_token_to_piece(vocab, token_id, piece, sizeof(piece), 0, true);
        if (piece_length < 0) {
            break;
        }

        {
            std::lock_guard<std::mutex> lock(g_mutex);
            g_last_response->append(piece, static_cast<size_t>(piece_length));
        }

        llama_sampler_accept(sampler, token_id);

        llama_batch_free(batch);
        batch = llama_batch_get_one(&token_id, 1);
        batch.logits[0] = true;
        generated += 1;
    }

    llama_batch_free(batch);
    llama_sampler_free(sampler);

    std::lock_guard<std::mutex> lock(g_mutex);
    return g_last_response ? g_last_response->c_str() : "";
}

void llama_cancel(void) {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_cancel_requested = true;
}
