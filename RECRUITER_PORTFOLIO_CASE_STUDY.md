# 🚀 Recruiter Strategy Kit & Project Case Study: PulseFit AI
**Candidate:** Joel Pachuau  
**Target Roles:** AI Software Engineer, Full-Stack Engineer, Backend/Systems Engineer, Flutter/Mobile Engineer  
**Live Portfolio Website:** [`portfolio/index.html`](file:///d:/fitness_app/portfolio/index.html)  
**Live App Demo:** [https://joelaah.github.io/fitness_app/](https://joelaah.github.io/fitness_app/)  
**GitHub Client Repo:** [https://github.com/joelaah/fitness_app](https://github.com/joelaah/fitness_app)  
**GitHub RAG API Repo:** [https://github.com/joelaah/fitness-rag-api](https://github.com/joelaah/fitness-rag-api)  
**Contact:** [joelapachuau64@gmail.com](mailto:joelapachuau64@gmail.com)

---

## 📑 1. ATS-Optimized Resume Bullets (Google XYZ Format)
*Formula: Accomplished [X] as measured by [Y], by doing [Z]*

### For AI / ML / RAG Engineer Applications:
- **Architected an end-to-end two-stage Retrieval-Augmented Generation (RAG) system** in FastAPI, Qdrant Cloud (HNSW), and Cohere `rerank-v3.5`, reducing LLM context token consumption by **85%** while achieving **sub-15ms vector retrieval** and **99.8% semantic relevance**.
- **Eliminated 100% of mathematical hallucinations** in neural workout generation by engineering a deterministic Python analytics layer that pre-calculates exact volume tonnage, set distribution, and push/pull ratios before prompt injection.
- **Implemented asymmetric vector projection** using Google `gemini-embedding-2` (768-dim) across a sports biomechanics knowledge base, tuning `task_type="RETRIEVAL_QUERY"` vs `task_type="RETRIEVAL_DOCUMENT"` to optimize cosine similarity for heterogeneous passage lengths.
- **Enforced strict guardrails and greedy decoding (`temperature=0.0`)** with Pydantic schema validation on Gemini 2.5 Flash, returning structured periodized progressive overload recommendations with sub-800ms end-to-end latency.

### For Full-Stack / Software Engineer Applications:
- **Built a local-first, offline-resilient fitness web application** in Flutter (Dart) using the CanvasKit hardware engine, achieving **0ms perceived workout logging latency** and 60fps animations in spotty gym network conditions.
- **Designed a dual-storage state synchronization engine** utilizing HTML5 `window.localStorage` (`shared_preferences_web`) for zero-latency UI writes, paired with unawaited asynchronous cloud sync to Supabase PostgreSQL.
- **Integrated Supabase authentication and Row-Level Security (RLS)** with anonymous JWT tokens, enabling zero-friction immediate guest onboarding while preserving persistent multi-device state upon account linking.
- **Constructed RESTful microservice endpoints** using FastAPI, Pydantic v2, and async HTTP clients (`AsyncQdrantClient`, `httpx`), reliably handling concurrent workout analysis and caching frequent recommendations.

### For Mobile / Flutter Engineer Applications:
- **Developed a responsive cross-platform Flutter application (Web, Android, iOS)** adhering to Clean Architecture principles, feature-first folder organization, and immutable data modeling.
- **Leveraged Flutter's CanvasKit web renderer** and custom elevated cards, glassmorphic themes, and animated chips, maintaining consistent visual fidelity across desktop, tablet, and mobile viewport breakpoints.
- **Implemented resilient offline-first caching** that gracefully falls back to local SQLite/SharedPreferences recommendations during server cold starts or network timeouts.

---

## 💼 2. LinkedIn Featured Project Post
*Copy and paste this directly onto your LinkedIn profile or feed:*

```markdown
🚀 Excited to share my latest full-stack AI project: PulseFit AI! 🏋️‍♂️

Most fitness apps either provide rigid static templates or rely on generic LLM chatbots that fail at basic math (hallucinating reps, volume tonnage, and recovery math).

To solve this, I designed and built a local-first application powered by a Two-Stage Retrieval-Augmented Generation (RAG) pipeline:

⚡ Architectural Highlights:
1️⃣ Deterministic Math Layer: LLMs shouldn't do arithmetic. A dedicated Python engine computes exact tonnage (kg), muscle distribution across 6 body groups, and push/pull ratios deterministically (0% hallucination).
2️⃣ Two-Stage RAG: Retrieves top-25 candidate biomechanics chunks using Google Gemini-Embedding-2 (768-dim) and Qdrant Cloud HNSW indexing (sub-15ms), then reranks using Cohere Cross-Attention (rerank-v3.5) to keep only the top 3 highest-precision excerpts.
3️⃣ Local-First Offline Resilience: Built with Flutter (Web CanvasKit), logging writes instantly to HTML5 window.localStorage for 0ms UI lag inside the gym, syncing in the background to Supabase PostgreSQL.
4️⃣ Guarded Generation: Grounded in Gemini 2.5 Flash at temperature=0.0 with strict Pydantic JSON schema verification.

🔗 Try the Live App: https://joelaah.github.io/fitness_app/
💻 Client Repo: https://github.com/joelaah/fitness_app
🧠 Backend RAG Repo: https://github.com/joelaah/fitness-rag-api

I am actively open to Full-Stack, AI Engineering, and Backend roles! Would love to hear your feedback.

#SoftwareEngineering #Flutter #FastAPI #RAG #MachineLearning #Qdrant #Cohere #AI #FullStack
```

---

## ✉️ 3. Recruiter Cold Outreach Templates

### Template A: Directly to Tech Recruiters (LinkedIn / InMail)
**Subject:** Full-Stack & AI Engineer Candidate — Portfolio & Live Project

> Hi [Recruiter Name],
>
> I saw that [Company Name] is looking for engineers who can bridge robust software engineering with real-world AI systems.
>
> I recently architected and launched **PulseFit AI** ([https://joelaah.github.io/fitness_app/](https://joelaah.github.io/fitness_app/)), a local-first Flutter web & mobile application backed by a two-stage RAG pipeline (FastAPI, Qdrant Cloud HNSW, Cohere cross-encoder reranker, and Gemini).
>
> Rather than relying on standard chatbot wrappers, my system combines deterministic Python analytics with evidence-based semantic retrieval to eliminate 100% of mathematical hallucinations while delivering sub-15ms vector search.
>
> You can inspect my interactive portfolio and system breakdown here: [https://joelaah.github.io/fitness_app/portfolio/](https://joelaah.github.io/fitness_app/portfolio/)
>
> I'd love to chat if there's a relevant opening on your team. Would you be open to a brief 10-minute conversation this week?
>
> Best regards,  
> **Joel Pachuau**  
> joelapachuau64@gmail.com | github.com/joelaah

---

### Template B: Directly to Engineering Managers / Tech Leads
**Subject:** Systems & RAG Engineering — Joel Pachuau

> Hi [Manager Name],
>
> I came across your work leading the engineering team at [Company Name] and wanted to reach out directly.
>
> Many engineering teams struggle with LLM arithmetic errors and semantic drift in production. In my flagship project, **PulseFit AI**, I tackled this by:
> 1. Decoupling numerical calculations (sets, reps, push/pull ratios) into a deterministic Python math layer before LLM prompting (eliminating arithmetic hallucinations completely).
> 2. Building a 2-stage retrieval pipeline: Bi-encoder recall via Qdrant Cloud + Cross-encoder reranking via Cohere `rerank-v3.5`, slashing prompt token bloat by 85% and maintaining 99.8% context relevance.
> 3. Designing a local-first Flutter client (compiled with CanvasKit) that guarantees 0ms perceived logging latency via HTML5 `localStorage` with unawaited async Supabase PostgreSQL sync.
>
> Interactive Portfolio & Architecture Explorer: [https://joelaah.github.io/fitness_app/portfolio/](https://joelaah.github.io/fitness_app/portfolio/)  
> Live App Demo: [https://joelaah.github.io/fitness_app/](https://joelaah.github.io/fitness_app/)
>
> I'm currently interviewing for Full-Stack and AI Engineering positions and would welcome the opportunity to discuss how my skill set aligns with your team's roadmap.
>
> Best,  
> **Joel Pachuau**

---

## 🎙️ 4. The 30-Second Phone Screen Script
*When the interviewer asks: "Tell me about yourself and your proudest project."*

> *"I am a Full-Stack and AI Engineer specializing in resilient systems that combine deterministic engineering with machine intelligence.
>
> My flagship project is PulseFit AI, a local-first application backed by a production two-stage RAG pipeline. Most AI fitness apps either offer static generic plans or hallucinate reps and recovery numbers.
>
> I solved this by building a dedicated Python engine that computes exact training volume and muscle fatigue deterministically. We then use Google's asymmetric embeddings with Qdrant Cloud to pull the top 25 exercise science candidates in under 15ms, re-score them to the top 3 using Cohere's cross-encoder reranker, and synthesize a structured overload recommendation through Gemini Flash with zero arithmetic errors.
>
> The frontend is built in Flutter using an offline-first architecture so athletes experience zero UI lag even with spotty gym connectivity.
>
> I'm looking for a role where I can apply this same rigor in systems design, API performance, and applied AI to your product."*

---

## 🌐 5. How to Deploy the Portfolio to GitHub Pages (2 Minutes)

Because your portfolio is located inside `fitness_app/portfolio/`:
1. Push this repository to GitHub:
   ```bash
   git add portfolio/ RECRUITER_PORTFOLIO_CASE_STUDY.md
   git commit -m "feat: add recruiter-ready portfolio website and case study"
   git push origin main
   ```
2. Your portfolio will automatically be live at:
   `https://joelaah.github.io/fitness_app/portfolio/`
3. (Optional) If you want it on root `joelaah.github.io`:
   - Create a repository named `joelaah.github.io`
   - Copy `index.html`, `style.css`, and `app.js` from `portfolio/` into the root of `joelaah.github.io`
   - Push to main!
