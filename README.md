Paste into console console terminal. Creates a personality folder, a settings folder, a installed models folder and a launcher, all are linked and work together.
Go into config and paste a link to the hugging face model you want.

The script handles all dependencies and builds everything you need.

## What Gets Created

- **Launch-Llama.desktop** – Desktop launcher icon to start the chat
- **Llama/llama-config.txt** – Model selection and generation settings
- **Llama/personality.txt** – AI system prompt/personality
- **Llama/models/** – Downloaded models stored here

## First Launch

1. Open `Llama/llama-config.txt`
2. Paste a HuggingFace URL after `CURRENT_MODEL`
3. Double-click `Launch-Llama.desktop` to start
4. Model downloads on first launch, then runs offline

### Generation Settings

- **THREADS** – CPU threads (4 safe for Pi 5, try 3 to leave headroom)
- **TEMP** – Temperature (0.0–2.0, lower = focused, higher = creative)
- **CONTEXT** – Context window in tokens (4096 comfortable on Pi 5)
- **MAX_TOKENS** – Max response length (-1 = unlimited)
- **BATCH_SIZE** – Prompt processing batch (higher = faster, more RAM)
- **REPEAT_PENALTY** – Token repetition penalty (1.0 = off, 1.1 = mild)
- **TOP_K** – Limits to K most likely tokens
- **TOP_P** – Nucleus sampling cutoff
- **MIN_P** – Minimum token probability
- **SEED** – Random seed (-1 = random each run)

### Performance Settings

- **FLASH_ATTN** – Flash attention (on/off/auto) for faster inference
- **MLOCK** – Lock weights in RAM (on/off) to prevent disk swap

### AI Personality

Edit `Llama/personality.txt` to customize the system prompt. Default is "You are a helpful AI assistant."

## Performance Tips

- Start with smaller models (1-3B parameters)
- Reduce CONTEXT if running out of memory
- Use BATCH_SIZE=256 for slower systems
- FLASH_ATTN=auto generally optimal
- Set MLOCK=on if you have spare RAM

## Offline Operation

Once a model downloads, everything runs completely offline with no internet required. Models cache in `Llama/models/` and reuse on subsequent launches.
