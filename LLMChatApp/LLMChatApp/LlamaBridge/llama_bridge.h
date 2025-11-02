#pragma once

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void* llama_context_ref;

llama_context_ref llama_create_context_from_model_path(const char* model_path);
void llama_free_context(llama_context_ref context);
const char* llama_generate_response(llama_context_ref context, const char* prompt, double temperature, int max_tokens);
void llama_cancel(void);

#ifdef __cplusplus
}
#endif
