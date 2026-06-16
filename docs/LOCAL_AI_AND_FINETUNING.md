# Local open-source models + fine-tuning loop

This ERP's AI features (flux analysis, bill drafting, conversational entry,
NLP-to-SQL, bank-statement parsing) can run entirely on a **self-hosted open
model** — no Anthropic key — and can be **continuously fine-tuned on your own
data**. Two halves: (A) serve a local model, (B) train it.

## A. Run on a local model instead of Anthropic

All text AI goes through `VisionModelRouter`, which picks the provider from the
org's `OrgAiSettings`. Three providers:

| provider | serves with | baseUrl example |
|---|---|---|
| `CLAUDE` | Anthropic API (needs key) | — |
| `OLLAMA` | Ollama native `/api/chat` | `http://localhost:11434` |
| `OPENAI_COMPAT` | vLLM / LM Studio / llama.cpp / Ollama `/v1` | `http://localhost:8000` |

**Switch an org to a local model** (`PUT /api/v1/ai/settings`):

```json
{ "provider": "OPENAI_COMPAT", "baseUrl": "http://localhost:8000", "modelName": "katasticho-accounting" }
```

`OPENAI_COMPAT` is the recommended path — vLLM, LM Studio, llama.cpp's server,
text-generation-webui, and Ollama all expose `POST /v1/chat/completions`, so the
one client (`OpenAiCompatibleChatClient`) covers every serving engine, including
how you'll serve a fine-tuned adapter. App-wide default lives in
`app.ai.default-provider` / `app.ai.ollama-base-url` / `app.ai.ollama-model`.

No code change is needed to go local — flip the setting.

## B. Train / fine-tune on your own data

You do **not** train a model from scratch. You **fine-tune** an open base
(Llama 3.1/3.3, Qwen2.5, Mistral) with **LoRA/QLoRA** — runs on a single GPU.

### 1. Data is already being collected
Every AI Inbox decision is captured in `ai_training_example`:
`input_snapshot` (what the model saw), `ai_output` (what it proposed),
`human_output` (what the human accepted/corrected), `correction_type`
(ACCEPTED / MODIFIED / REJECTED), `task_type`. **This is a labeled dataset** —
the human's correction is the ground truth to imitate.

### 2. Export the dataset (in-app)
```
GET /api/v1/ai/training/summary               # how many examples accumulated
GET /api/v1/ai/training/export?goodOnly=true  # chat-format JSONL (ACCEPTED+MODIFIED)
GET /api/v1/ai/training/export?taskType=DRAFT_BILL
```
Returns NDJSON, one example per line, in the standard chat SFT shape:
```json
{"messages":[{"role":"system","content":"You are an Indian SMB accountant..."},
             {"role":"user","content":"<input_snapshot>"},
             {"role":"assistant","content":"<human_output>"}]}
```

### 3. Fine-tune offline (GPU job — outside this app)
The Spring app produces the dataset and consumes the resulting model; the actual
training is a separate Python job. Easiest path — **Unsloth** (or Axolotl):
```python
# pip install unsloth ; needs one GPU (a 7-8B model fits on 16-24GB with QLoRA)
from unsloth import FastLanguageModel
from trl import SFTTrainer
# load base (e.g. unsloth/Qwen2.5-7B-Instruct), attach LoRA, train on the JSONL
# (each line's messages[] is the conversation; assistant turn is the label)
```
Output: a LoRA adapter (and/or a merged GGUF).

### 4. Deploy the fine-tuned model
- **Ollama:** `ollama create katasticho-accounting -f Modelfile` (Modelfile
  `FROM` the base GGUF + `ADAPTER` the LoRA), then it's served at `:11434`.
- **vLLM:** `vllm serve <base> --enable-lora --lora-modules katasticho=<adapter>` → `:8000/v1`.

### 5. Register + switch (in-app)
Record the new version in `ai_model_registry` (via `AiModelRegistryService`) and
point the org at it by updating `OrgAiSettings.modelName`. You can A/B by giving
some orgs the new model and watching the accept-rate in the Inbox — which itself
feeds the next export. **That loop — review → export → fine-tune → deploy →
review — is the engine that makes the AI improve on your books over time.**

## Guidance
- Start by serving a strong instruct base locally (Qwen2.5-7B / Llama-3.1-8B) —
  it's already good at bill drafting and NL→SQL.
- Only fine-tune once you have a few hundred+ reviewed examples per task; below
  that, the base + good prompts win.
- Keep `CLAUDE` available as a fallback for hard tasks (vision/OCR especially) —
  the router is per-org, so you can mix.
