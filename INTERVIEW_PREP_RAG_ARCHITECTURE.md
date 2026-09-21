# 🏋️‍♂️ Full-Stack Fitness RAG Architecture — Technical Interview Prep Guide

> **Project Name:** Aura Fit / Fitness RAG App  
> **Tech Stack:** Flutter (Web & Mobile), FastAPI (Python), Qdrant Cloud (Vector DB), Google Gemini (`gemini-3.6-flash` & `gemini-embedding-2`), Cohere (`rerank-v3.5`), Supabase (PostgreSQL & Auth).  
> **Repository:** Local-First Offline Architecture + Cloud Vector RAG Pipeline.

---

## 🎯 1. The 30-Second Elevator Pitch

> *"I built Aura Fit, a local-first full-stack fitness application powered by a two-stage Retrieval-Augmented Generation (RAG) pipeline. While traditional fitness apps offer generic static plans or hallucination-prone LLM chatbots, my system combines deterministic Python analytics with evidence-based exercise science retrieval. It ingests user workout logs, deterministically calculates volume distribution across 6 standard muscle groups, retrieves hyper-relevant hypertrophy and recovery principles from a Qdrant Cloud vector database, re-scores them using a Cohere cross-encoder reranker, and prompts Google Gemini to produce mathematically grounded, periodized progressive overload recommendations."*

---

## 🏗️ 2. End-to-End System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       FLUTTER CLIENT (Web & Mobile)                     │
│  - Local-First Storage: HTML5 window.localStorage / SharedPreferences   │
│  - Zero-latency UI updates & offline workout logging                   │
│  - Anonymous Auth UUID via Supabase Client                             │
└──────────────────┬────────────────────────────────────┬─────────────────┘
                   │ 1. Asynchronous Sync               │ 2. POST /recommend
                   ▼                                    ▼
┌──────────────────────────────────────┐    ┌─────────────────────────────┐
│       SUPABASE (PostgreSQL)          │    │     FASTAPI BACKEND         │
│  - public.workout_sessions           │    │  - api.py                   │
│  - public.workout_exercises          │    │  - JWT & Anonymous Auth     │
│  - public.workout_sets               │    │  - Deterministic Math Engine│
│  - public.ai_recommendations         │    └──────────────┬──────────────┘
└──────────────────────────────────────┘                   │
                                                           │
        ┌──────────────────────────────────────────────────┴───────────────┐
        ▼                                                                  ▼
┌──────────────────────────────────────────┐    ┌──────────────────────────────────────────┐
│   STAGE 1: BROAD VECTOR RECALL (Bi-Encoder)│    │       DETERMINISTIC STATS ENGINE         │
│  - Model: gemini-embedding-2 (768 dims)  │    │  - Computes total volume (kg)            │
│  - Query: task_type="RETRIEVAL_QUERY"    │    │  - Muscle group volume breakdown         │
│  - Vector DB: Qdrant Cloud (Cosine, HNSW)│    │  - Identifies neglected muscle groups    │
│  - Fetches: Top-25 Candidate Chunks      │    │  - Calculates training frequency         │
└──────────────────┬───────────────────────┘    └──────────────────┬───────────────────────┘
                   │                                               │
                   ▼                                               │
┌──────────────────────────────────────────┐                       │
│  STAGE 2: PRECISION RERANKING (Cross-Enc) │                       │
│  - Model: Cohere rerank-v3.5             │                       │
│  - Computes full token-level query-doc   │                       │
│    cross-attention scores                │                       │
│  - Filters: Top-25 down to Top-3 chunks  │                       │
└──────────────────┬───────────────────────┘                       │
                   │                                               │
                   └───────────────────────┬───────────────────────┘
                                           │
                                           ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                      STAGE 3: GROUNDED GENERATION                        │
│  - Model: Google Gemini (gemini-3.6-flash)                               │
│  - Temperature: 0.0 (strictly deterministic and grounded)                │
│  - System Prompt: Guardrails against hallucination & medical advice      │
│  - Output: Structured JSON (Progression, Recovery, Next Session Focus)   │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 🔬 3. Deep Dive into Technical Decisions

### A. Why Two-Stage Retrieval (Bi-Encoder + Cross-Encoder)?
- **The Problem:** Single-stage vector search (bi-encoders) compresses whole paragraphs into a single fixed vector (768 floats). While blazing fast (millisecond search across millions of vectors via HNSW index), it suffers from semantic compression loss and cannot model fine-grained interaction between individual query terms and document words.
- **The Solution:**
  1. **Stage 1 (Bi-encoder / Qdrant)**: Casts a wide net, pulling the **Top-25** candidates in ~15ms.
  2. **Stage 2 (Cross-encoder / Cohere `rerank-v3.5`)**: Jointly attends over query tokens and document tokens simultaneously, re-scoring each chunk. We take the **Top-3** highest-precision chunks.
- **The Result:** We achieve high recall without blowing up LLM prompt token costs or diluting context with irrelevant information.

### B. Why Separate Deterministic Math from LLM Generation?
- **The Problem:** LLMs are notorious for failing at basic arithmetic (calculating total volume `reps × weight`, summing sets across days, or tracking weekly workout frequency).
- **The Solution:** In `api.py`, `calculate_deterministic_statistics()` calculates:
  - Exact total tonnage volume (kg)
  - Volume breakdown per muscle group (Chest, Back, Legs, Shoulders, Arms, Core)
  - Most trained vs. recently neglected muscle groups
  - Weekly training frequency and days between workouts
- **The Synthesis:** The Python engine sends these *exact, verified numbers* + *retrieved scientific literature* to Gemini. The LLM acts purely as an analytical reasoning and formatting engine, eliminating mathematical hallucinations.

### C. Chunking & Ingestion Strategy
- **Chunk Size:** 600 characters with a 60-character overlap (~100–120 tokens).
- **Paragraph Awareness:** Uses double-newline (`\n\n`) boundaries to ensure complete thoughts and exercises aren't severed mid-sentence.
- **Task Types:** 
  - Embeddings during ingestion use `task_type="RETRIEVAL_DOCUMENT"`.
  - Embeddings during user search use `task_type="RETRIEVAL_QUERY"`.
  This enables asymmetric semantic search tuned by Google for matching short queries to long informational passages.

### D. Client Storage & Web Offline-First Architecture
- **Web Storage:** On web browsers, Flutter compiles with `shared_preferences_web`, which binds directly to the HTML5 `window.localStorage` API.
- **Local-First Pattern:** The app saves instantly to `localStorage` so the user experiences zero UI latency even with spotty gym Wi-Fi.
- **Cloud Sync:** Sessions are simultaneously synced in the background to Supabase PostgreSQL (`workout_sessions`, `workout_exercises`, `workout_sets`) under an anonymous user UUID generated via `signInAnonymously()`.

---

## 💬 4. Top 12 Technical Interview Questions & Model Answers

### Q1: "Can you describe the architecture of your RAG pipeline?"
> *"My RAG pipeline is a production-grade, two-stage system. When a recommendation is requested:
> 1. The client sends recent completed workout sessions.
> 2. My FastAPI backend calculates deterministic training statistics (volume per muscle group, frequency, neglected muscles).
> 3. We formulate an asymmetric retrieval query and embed it using Google’s `gemini-embedding-2` (768 dimensions).
> 4. We execute a cosine similarity search against Qdrant Cloud to fetch the top 25 candidate chunks from our scientific exercise library.
> 5. We pass those 25 candidates to Cohere’s `rerank-v3.5` cross-encoder to re-score token-level relevance and select the top 3 chunks.
> 6. Finally, we pass the deterministic stats + the top 3 reranked chunks into Gemini `gemini-3.6-flash` at `temperature=0.0` with strict guardrails to return structured overload and recovery advice."*

---

### Q2: "Why did you add a Cohere reranker instead of just setting Qdrant top_k=3?"
> *"Because bi-encoders and cross-encoders have fundamental trade-offs:
> - **Bi-encoders (Qdrant)** compute embeddings for queries and documents independently. They are $O(1)$ fast using vector indexes like HNSW, but cannot capture fine token-to-token interactions. Top-3 from vector search often includes chunks that match keywords or high-level semantics but miss specific nuances.
> - **Cross-encoders (Cohere Rerank)** feed the query and document together into the transformer attention layers ($O(N)$ computation). They are too slow to run across an entire database, but exceptionally accurate over a small candidate set.
> By pulling 25 candidates with Qdrant and reranking to 3 with Cohere, we get the speed of vector search and the precision of full cross-attention."*

---

### Q3: "How do you prevent hallucinations and ensure user safety?"
> *"We implement defense-in-depth across 4 layers:
> 1. **Zero Temperature (`0.0`):** Minimizes creative variance and forces deterministic greedy decoding.
> 2. **Strict System Instruction:** The prompt explicitly mandates: *'Answer ONLY using the provided context. If the answer cannot be found in the context, respond with "I do not know". Do not speculate or infer.'*
> 3. **Deterministic Math:** The LLM does not calculate volume or reps. All statistics are pre-computed in Python and passed as factual ground truth.
> 4. **Medical Guardrail:** The system prompt explicitly forbids diagnosing injuries or prescribing rehabilitation, instructing the user to consult medical professionals if pain is mentioned."*

---

### Q4: "How does the app work offline and on the web without a file system?"
> *"We follow a local-first architecture. On mobile and web, Flutter’s `shared_preferences` package abstracts platform-specific storage. On Web, it compiles to `shared_preferences_web`, writing directly to the browser's HTML5 `window.localStorage`.
> This guarantees zero-latency workout logging and offline support. In the background, when internet connectivity is available, an unawaited async service syncs completed sessions to Supabase PostgreSQL using anonymous JWT authentication."*

---

### Q5: "What embedding model did you choose and why?"
> *"I chose Google's `gemini-embedding-2` with 768 dimensions. It natively supports asymmetric retrieval tasks via explicit `task_type` flags (`RETRIEVAL_DOCUMENT` during offline ingestion and `RETRIEVAL_QUERY` during real-time retrieval). 768 dimensions provides a sweet spot balancing semantic expressiveness with memory footprint in Qdrant."*

---

### Q6: "Why did you use Qdrant over pgvector or Pinecone?"
> *"Three reasons:
> 1. **Payload-based Filtering:** Qdrant allows creating keyword indexes directly on JSON payload fields (like `category`), allowing us to filter candidates during vector search without post-filtering.
> 2. **HNSW & Quantization:** Qdrant’s native Rust implementation delivers sub-10ms nearest neighbor search.
> 3. **Separation of Concerns:** We used Supabase PostgreSQL for relational transactional data (user profiles, sessions, sets) and dedicated Qdrant Cloud for high-dimensional vector search."*

---

### Q7: "How did you solve the Cold Start problem for brand new users?"
> *"If a user has 0 logged workouts, `calculate_deterministic_statistics()` flags `sessions_analyzed: 0`. Instead of failing or prompting the LLM with empty stats, the API automatically triggers a dedicated introductory baseline pipeline that retrieves foundational beginner adaptation principles from our knowledge base and returns a starter split recommendation."*

---

### Q8: "What was your chunking strategy and why?"
> *"We used a paragraph-aware sliding window chunker:
> - 600 characters chunk size (~100 words).
> - 60 characters overlap (~10 words) to prevent semantic fragmentation at boundaries.
> - We chunked on double newlines (`\n\n`) first to keep exercise descriptions and scientific principles self-contained. Chunks that are too large dilute vector embeddings; chunks that are too small lack contextual coherence. 600 characters was the empirical sweet spot."*

---

### Q9: "How do you authenticate requests to the RAG API?"
> *"We use Supabase JWT validation. The Flutter app initializes anonymous authentication on first launch, receiving a cryptographically signed JWT. When making requests to `/recommend` or `/chat`, the bearer token is sent in the `Authorization` header. The FastAPI backend verifies the token against Supabase auth public keys and extracts the `user_id`. The client is never allowed to spoof or specify another user's ID."*

---

### Q10: "How did you optimize API latency?"
> *"1. **Asynchronous I/O:** The ingestion and query pipelines use `AsyncQdrantClient` and `client.aio` for concurrent batch requests.
> 2. **Strict Pruning (Top-3):** Reranking to only the top 3 chunks keeps LLM input tokens small (~800 tokens), reducing Time-To-First-Token (TTFT) on Gemini Flash.
> 3. **Greedy Sampling:** `temperature=0.0` skips complex top-p/top-k probability sampling, speeding up generation."*

---

### Q11: "How would you scale this system to 100,000 daily active users?"
> *"1. **Vector Caching:** Cache query vector embeddings and top-retrieved documents for repeated/similar questions using Redis.
> 2. **Recommendation Pre-computation:** Instead of running the recommendation pipeline when the user opens the app, trigger a background worker (via Celery/RabbitMQ) upon the `workout_finished` webhook event to pre-compute and store recommendations in `public.ai_recommendations`.
> 3. **Qdrant Scalar Quantization:** Enable int8 scalar quantization in Qdrant to reduce vector memory usage by 75% with negligible accuracy drop."*

---

### Q12: "If you had two more weeks, what would you improve?"
> *"1. **Hybrid Sparse-Dense Search (BM25 + Dense):** Add BM25 keyword matching alongside dense embeddings for exact exercise names (e.g., 'RDL' vs 'Romanian Deadlift').
> 2. **RAG Triad Evaluation:** Implement automated evaluation using Ragas or TruLens to continuously measure Faithfulness, Answer Relevance, and Context Precision.
> 3. **Fine-Tuning:** Fine-tune the reranker model on specific fitness domain terminology."*

---

## 📖 5. Key Terminology Cheat Sheet (Sound Like a Senior AI Engineer)

| Term | Definition to Use in Interview |
|---|---|
| **Bi-Encoder** | A model that embeds query and document independently into fixed-length vectors. Used for high-speed broad retrieval ($O(1)$ with index). |
| **Cross-Encoder** | A model that attends over query and document simultaneously. Highly accurate for reranking candidates ($O(N)$). |
| **HNSW** | *Hierarchical Navigable Small World* — the graph-based algorithm used by Qdrant for approximate nearest neighbor (ANN) search. |
| **Cosine Similarity** | Metric measuring the cosine of the angle between two normalized vectors, invariant to vector magnitude: $\frac{A \cdot B}{\|A\|\|B\|}$. |
| **Local-First** | Architectural pattern where local client storage is the primary source of truth, syncing asynchronously to the cloud. |
| **Asymmetric Retrieval** | When query and document differ significantly in length or style (e.g. short question vs long passage). Requires distinct query/doc embedding task types. |
| **Context Grounding** | Forcing the language model to base its response strictly on retrieved excerpts rather than pre-trained parametric weights. |
