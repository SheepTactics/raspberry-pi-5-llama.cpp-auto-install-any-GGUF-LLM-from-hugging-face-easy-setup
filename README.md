Just Paste all in one into the console terminal. It creates a `Llama` folder on your Desktop containing the config, personality file, and models directory, plus a desktop launcher. Everything is linked and works together.

Go into `llama-config.txt`, set the `CURRENT_MODEL` to a Hugging Face model URL (or publisher/modelname), then double-click the launcher. The script handles all dependencies, builds llama.cpp with HTTPS support, and manages everything with no bulky overhead like Python or Ollama.

## What Gets Created

* **Launch-Llama.desktop** – Desktop launcher icon to start the chat session
* **Desktop/Llama/llama-config.txt** – Model selection and all generation settings
* **Desktop/Llama/personality.txt** – AI system prompt / personality
* **Desktop/Llama/models/** – Downloaded models are automatically stored and cached here

## First Launch

1. Open `Desktop/Llama/llama-config.txt`
2. Paste a HuggingFace GGUF model URL or `publisher/modelname` after `CURRENT_MODEL=`
3. (Optional) Adjust any generation or performance settings
4. Double-click **Launch-Llama.desktop** to start
5. The model will download on first use, then run fully offline

The config file automatically updates with a list of all installed models for easy switching.

### Easy txt Settings

* **THREADS** – CPU threads to use (4 is safe for Pi 5, try 3 to leave headroom)
* **TEMP** – Temperature (0.0–2.0, lower = more focused, higher = more creative)
* **CONTEXT** – Context window size in tokens (4096 is comfortable on Pi 5)
* **MAX_TOKENS** – Maximum tokens to generate (-1 = no limit)
* **BATCH_SIZE** – Prompt processing batch size (higher = faster, more RAM)
* **REPEAT_PENALTY** – Repetition penalty (1.0 = off, 1.1+ to reduce loops)
* **TOP_K** – Top-K sampling
* **TOP_P** – Top-P (nucleus) sampling
* **MIN_P** – Min-P sampling
* **SEED** – Random seed (-1 = random each run)
* **REASONING_BUDGET** – For reasoning models only. 0 = thinking disabled. 1+ sets token budget for reasoning steps.
* **EMOJI_ALLOW** – `true` allows emojis. `false` restricts output to ASCII only (blocks emojis).
* **FLASH_ATTN** – Flash Attention (`true`/`false`/`auto`) for faster inference and lower memory use
* **MLOCK** – Lock model in RAM (`true`/`false`) to prevent swapping to disk

### AI Personality
Edit `Desktop/Llama/personality.txt` to customize the system prompt.

## Performance Tips

* Start with smaller models (1-3B parameters) for best speed on Raspberry Pi 5
* Reduce `CONTEXT` if you run out of memory
* Lower `BATCH_SIZE` (e.g. 256) on slower systems
* `FLASH_ATTN=auto` is usually the best setting
* Enable `MLOCK=true` if you have enough free RAM

## Offline Operation
Once downloaded, models run completely offline. They are cached in `Llama/models/` and reused on future launches.

## Want Any Features or Updates?
Just let me know and I'll add them.
