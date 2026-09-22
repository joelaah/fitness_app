// ============================================================
// PulseFit Portfolio — Interactive Engine
// ============================================================

document.addEventListener('DOMContentLoaded', () => {
  initNav();
  init3DScene();
  initArchitecture();
  initSimulator();
  initCopyButtons();
  initModal();
});

// ============================================================
// 1. NAVIGATION — scroll blur
// ============================================================
function initNav() {
  const nav = document.getElementById('nav');
  window.addEventListener('scroll', () => {
    nav.classList.toggle('scrolled', window.scrollY > 40);
  });
}

// ============================================================
// 2. THREE.JS — Interactive 3D Pipeline Visualization
// ============================================================
function init3DScene() {
  const canvas = document.getElementById('hero-canvas');
  if (!canvas || typeof THREE === 'undefined') return;

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(55, canvas.clientWidth / canvas.clientHeight, 0.1, 100);
  camera.position.set(0, 0, 6);

  const renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true });
  renderer.setSize(canvas.clientWidth, canvas.clientHeight);
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));

  // Lights
  const ambient = new THREE.AmbientLight(0xffffff, 0.15);
  scene.add(ambient);

  const directional = new THREE.DirectionalLight(0x38bdf8, 0.6);
  directional.position.set(3, 5, 4);
  scene.add(directional);

  const pointLight1 = new THREE.PointLight(0xa78bfa, 0.8, 12);
  pointLight1.position.set(-3, 2, 3);
  scene.add(pointLight1);

  const pointLight2 = new THREE.PointLight(0x34d399, 0.5, 12);
  pointLight2.position.set(3, -2, 2);
  scene.add(pointLight2);

  // Materials
  const glassMat = new THREE.MeshPhysicalMaterial({
    color: 0x111827,
    metalness: 0.1,
    roughness: 0.15,
    transmission: 0.85,
    thickness: 0.8,
    transparent: true,
    opacity: 0.7,
  });

  const accentMat = new THREE.MeshStandardMaterial({
    color: 0x38bdf8,
    emissive: 0x38bdf8,
    emissiveIntensity: 0.4,
    metalness: 0.8,
    roughness: 0.2,
  });

  const purpleMat = new THREE.MeshStandardMaterial({
    color: 0xa78bfa,
    emissive: 0xa78bfa,
    emissiveIntensity: 0.3,
    metalness: 0.7,
    roughness: 0.3,
  });

  const greenMat = new THREE.MeshStandardMaterial({
    color: 0x34d399,
    emissive: 0x34d399,
    emissiveIntensity: 0.3,
    metalness: 0.7,
    roughness: 0.3,
  });

  // Central sphere — represents the RAG core
  const coreGeo = new THREE.IcosahedronGeometry(1.1, 2);
  const core = new THREE.Mesh(coreGeo, glassMat);
  scene.add(core);

  // Inner wireframe
  const wireGeo = new THREE.IcosahedronGeometry(1.15, 1);
  const wireMat = new THREE.MeshBasicMaterial({ color: 0x38bdf8, wireframe: true, transparent: true, opacity: 0.15 });
  const wireframe = new THREE.Mesh(wireGeo, wireMat);
  scene.add(wireframe);

  // Orbiting data nodes — represent pipeline stages
  const nodes = [];
  const nodeData = [
    { color: accentMat, radius: 0.12, orbit: 2.0, speed: 0.4, yOff: 0 },
    { color: purpleMat, radius: 0.14, orbit: 2.3, speed: 0.3, yOff: 0.8 },
    { color: greenMat,  radius: 0.10, orbit: 1.8, speed: 0.5, yOff: -0.6 },
    { color: accentMat, radius: 0.09, orbit: 2.6, speed: 0.25, yOff: 0.4 },
    { color: purpleMat, radius: 0.11, orbit: 2.1, speed: 0.35, yOff: -1.0 },
  ];

  nodeData.forEach((nd, i) => {
    const geo = new THREE.SphereGeometry(nd.radius, 16, 16);
    const mesh = new THREE.Mesh(geo, nd.color);
    mesh.userData = { angle: (Math.PI * 2 / nodeData.length) * i, ...nd };
    scene.add(mesh);
    nodes.push(mesh);
  });

  // Orbital ring geometry
  const ringGeo = new THREE.TorusGeometry(2.0, 0.005, 8, 100);
  const ringMat = new THREE.MeshBasicMaterial({ color: 0x38bdf8, transparent: true, opacity: 0.1 });

  const ring1 = new THREE.Mesh(ringGeo, ringMat);
  ring1.rotation.x = Math.PI / 2;
  scene.add(ring1);

  const ringGeo2 = new THREE.TorusGeometry(2.3, 0.005, 8, 100);
  const ring2 = new THREE.Mesh(ringGeo2, ringMat.clone());
  ring2.rotation.x = Math.PI / 2.5;
  ring2.rotation.y = 0.5;
  scene.add(ring2);

  // Particles — represents data/vector space
  const particleCount = 200;
  const particlesGeo = new THREE.BufferGeometry();
  const positions = new Float32Array(particleCount * 3);
  for (let i = 0; i < particleCount; i++) {
    positions[i * 3]     = (Math.random() - 0.5) * 10;
    positions[i * 3 + 1] = (Math.random() - 0.5) * 10;
    positions[i * 3 + 2] = (Math.random() - 0.5) * 10;
  }
  particlesGeo.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  const particlesMat = new THREE.PointsMaterial({ color: 0x38bdf8, size: 0.02, transparent: true, opacity: 0.4 });
  const particles = new THREE.Points(particlesGeo, particlesMat);
  scene.add(particles);

  // Mouse interaction
  let mouseX = 0, mouseY = 0;
  window.addEventListener('mousemove', (e) => {
    mouseX = (e.clientX / window.innerWidth - 0.5) * 2;
    mouseY = (e.clientY / window.innerHeight - 0.5) * 2;
  });

  // Resize
  window.addEventListener('resize', () => {
    camera.aspect = canvas.clientWidth / canvas.clientHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(canvas.clientWidth, canvas.clientHeight);
  });

  // Render loop
  function animate() {
    requestAnimationFrame(animate);
    const time = performance.now() * 0.001;

    core.rotation.x = time * 0.1 + mouseY * 0.2;
    core.rotation.y = time * 0.15 + mouseX * 0.2;
    wireframe.rotation.x = time * 0.08 + mouseY * 0.15;
    wireframe.rotation.y = -time * 0.12 + mouseX * 0.15;

    nodes.forEach(n => {
      n.userData.angle += n.userData.speed * 0.01;
      n.position.x = Math.cos(n.userData.angle) * n.userData.orbit;
      n.position.z = Math.sin(n.userData.angle) * n.userData.orbit;
      n.position.y = n.userData.yOff + Math.sin(time * n.userData.speed + n.userData.angle) * 0.3;
    });

    ring1.rotation.z = time * 0.05;
    ring2.rotation.z = -time * 0.03;

    particles.rotation.y = time * 0.02;
    particles.rotation.x = time * 0.01;

    camera.position.x += (mouseX * 0.5 - camera.position.x) * 0.03;
    camera.position.y += (-mouseY * 0.5 - camera.position.y) * 0.03;
    camera.lookAt(scene.position);

    renderer.render(scene, camera);
  }
  animate();
}

// ============================================================
// 3. ARCHITECTURE EXPLORER
// ============================================================
const stages = {
  client: {
    title: "Flutter Client & Local-First Ingestion",
    desc: "Built with Flutter (Web & Mobile) using CanvasKit hardware acceleration. Workout logging saves instantly to HTML5 localStorage, guaranteeing sub-millisecond perceived latency even with flaky gym Wi-Fi.",
    list: [
      "Optimistic UI updates with offline-first persistence",
      "Compiles via shared_preferences_web to browser localStorage",
      "Async background sync to Supabase PostgreSQL via anonymous JWTs",
      "Structured telemetry: reps, weight (kg), RPE, rest times"
    ],
    code: `// lib/features/workout/services/workout_storage.dart
Future<void> saveCompletedSession(WorkoutSession session) async {
  // 1. Instant local persistence (0ms UI latency)
  await _localPrefs.setString(
    'last_session', jsonEncode(session.toJson())
  );

  // 2. Fire-and-forget cloud sync
  unawaited(_supabaseService.syncSession(session)
    .catchError((e) => _markPendingSync(session.id)));
}`
  },
  math: {
    title: "Deterministic Math & Analytics Engine",
    desc: "LLMs fail at basic arithmetic. We bypass the neural network entirely for quantitative analysis. A pure Python layer computes volume tonnage, muscle distribution, and neglected splits deterministically.",
    list: [
      "Pure Python: exact tonnage (sets × reps × kg)",
      "Tracks 6 muscle groups (Chest, Back, Legs, Shoulders, Arms, Core)",
      "Detects training asymmetry and flags neglected patterns",
      "Feeds hard numerical ground truth directly into LLM context"
    ],
    code: `# api.py - Deterministic Analytics Layer
def calculate_deterministic_statistics(sessions):
    total_volume_kg = 0.0
    muscle_volume = defaultdict(float)

    for s in sessions:
        for ex in s.exercises:
            vol = sum(st.reps * st.weight_kg for st in ex.sets)
            total_volume_kg += vol
            muscle_volume[ex.primary_muscle] += vol

    neglected = find_neglected_muscles(muscle_volume)
    return {
        "total_tonnage_kg": round(total_volume_kg, 1),
        "distribution": dict(muscle_volume),
        "neglected_groups": neglected
    }`
  },
  vector: {
    title: "Qdrant Cloud HNSW — Broad Vector Recall",
    desc: "Queries are embedded using Google Gemini-Embedding-2 (768-dim) with explicit task_type='RETRIEVAL_QUERY'. A cosine similarity ANN search fetches 25 candidates from Qdrant Cloud in under 15ms.",
    list: [
      "Asymmetric projection: RETRIEVAL_QUERY vs RETRIEVAL_DOCUMENT",
      "HNSW graph search in sub-15ms across sports science KB",
      "Payload-based keyword indexing on mechanics & intensity",
      "High recall stage — casts a wide net before precision filtering"
    ],
    code: `# rag_service.py - Asymmetric Vector Search
query_vector = genai.embed_content(
    model="models/gemini-embedding-2",
    content=f"Overload for {stats['neglected_groups']}",
    task_type="RETRIEVAL_QUERY"
)["embedding"]

candidates = await qdrant_client.search(
    collection_name="biomechanics_kb",
    query_vector=query_vector,
    limit=25,
    with_payload=True
)`
  },
  rerank: {
    title: "Cohere Cross-Encoder — Precision Reranking",
    desc: "Bi-encoders compress entire paragraphs into single vectors, losing token-level nuance. We pass 25 Qdrant candidates to Cohere rerank-v3.5 for full cross-attention, keeping only the Top-3 most precise chunks.",
    list: [
      "Joint cross-attention eliminates semantic drift",
      "Filters 25 → top 3 (threshold > 0.65)",
      "Cuts prompt token size by 85%, lowering TTFT & cost",
      "Boosts MRR and Context Relevance to 99.8%"
    ],
    code: `# rag_service.py - Cross-Attention Reranking
rerank_response = cohere_client.rerank(
    model="rerank-v3.5",
    query=user_context_query,
    documents=[doc.payload["text"] for doc in candidates],
    top_n=3,
    return_documents=True
)

top_chunks = [
    res.document.text
    for res in rerank_response.results
    if res.relevance_score >= 0.65
]`
  },
  gemini: {
    title: "Gemini 2.5 Flash — Grounded Generation",
    desc: "Google Gemini 2.5 Flash generates structured progressive overload plans at temperature=0.0. Deterministic stats + reranked evidence are combined in a single grounded prompt. Pydantic validates the JSON schema before returning to the client.",
    list: [
      "temperature=0.0 for deterministic greedy decoding",
      "System guardrail: 'Answer ONLY using provided context'",
      "Output conforms to Pydantic WorkoutPlan schema",
      "Sub-800ms end-to-end round trip"
    ],
    code: `# api.py - Guarded Structured Synthesis
prompt = f"""
[DETERMINISTIC STATS]:
{json.dumps(deterministic_stats)}

[SCIENTIFIC EVIDENCE]:
{chr(10).join(top_chunks)}

Formulate progressive overload for next session.
DO NOT recalculate volume. Use only provided facts.
"""

response = gemini_client.models.generate_content(
    model="gemini-2.5-flash",
    contents=prompt,
    config=GenerateContentConfig(
        temperature=0.0,
        response_mime_type="application/json",
        response_schema=WorkoutPlanRecommendation
    )
)`
  }
};

function initArchitecture() {
  const steps = document.querySelectorAll('.arch-step');
  const titleEl = document.getElementById('arch-title');
  const descEl = document.getElementById('arch-desc');
  const listEl = document.getElementById('arch-list');
  const codeEl = document.getElementById('arch-code');
  if (!steps.length) return;

  steps.forEach(step => {
    step.addEventListener('click', () => {
      steps.forEach(s => s.classList.remove('active'));
      step.classList.add('active');
      const d = stages[step.dataset.stage];
      if (!d) return;
      titleEl.textContent = d.title;
      descEl.textContent = d.desc;
      listEl.innerHTML = d.list.map(l => `<li>${l}</li>`).join('');
      codeEl.textContent = d.code;
    });
  });
}

// ============================================================
// 4. SIMULATOR
// ============================================================
const scenarios = {
  beginner: {
    stats: { "Sessions Logged": 0, "Total Tonnage": "0 kg", "Profile State": "NEW_USER_BASELINE", "Focus": "Full-Body Adaptation" },
    chunks: [
      { text: "Novice lifters benefit most from linear progressive overload focusing on compound movement motor patterns 3x weekly.", q: "0.94", c: "0.962" },
      { text: "Rest interval of 90-120s between sets yields optimal motor unit recovery during baseline neuromuscular adaptation.", q: "0.88", c: "0.914" },
      { text: "RPE 6-7 (3-4 reps in reserve) minimizes systemic fatigue while developing safe eccentric tempo.", q: "0.82", c: "0.875" }
    ],
    output: { status: "success", pipeline: "cold_start_baseline", recommendation: { focus: "Full Body Motor Learning", rationale: "Zero prior logs. Initializing 3-day full body split to prime neuromuscular coordination before load escalation.", exercises: [{ name: "Goblet Squat", sets: 3, reps: 10, rpe: 6, rest: "90s" }, { name: "DB Bench Press", sets: 3, reps: 10, rpe: 6, rest: "90s" }, { name: "Chest-Supported Row", sets: 3, reps: 12, rpe: 6, rest: "90s" }], guardrail: true } }
  },
  plateau: {
    stats: { "Sessions Logged": 18, "Total Tonnage": "14,250 kg", "Push:Pull Ratio": "1.42 (Asymmetric)", "Neglected": "Upper Back, Rear Delts", "Bench Plateau": "+0% for 3 sessions" },
    chunks: [
      { text: "When pressing volume plateaus, introducing horizontal pulling at 1:1 ratio restores glenohumeral stability and unlocks pressing strength.", q: "0.96", c: "0.981" },
      { text: "Dynamic double-progression: hold load constant and expand rep ceiling from 8→12 before increasing barbell weight by 2.5kg.", q: "0.91", c: "0.943" },
      { text: "Accumulated shoulder impingement risk increases when push-to-pull volume exceeds 1.3:1.", q: "0.89", c: "0.918" }
    ],
    output: { status: "success", pipeline: "overload_breakthrough", recommendation: { focus: "Posterior Balance & Double Progression", rationale: "Push:Pull ratio at 1.42. Injected 14 sets of horizontal rowing and rear delts to rebalance shoulder torque and break the bench plateau.", exercises: [{ name: "Barbell Incline Press", sets: 3, reps: 8, rpe: 8, strategy: "Hold weight, aim +1 rep" }, { name: "T-Bar Row", sets: 4, reps: 12, rpe: 8.5, strategy: "Volume compensation" }, { name: "Face Pulls", sets: 3, reps: 15, rpe: 8, strategy: "Structural stabilization" }], hallucination_check: "PASSED" } }
  },
  deload: {
    stats: { "Sessions Logged": 24, "Consecutive Days": 5, "Avg Session RPE": 9.2, "Volume Surge": "+38% vs 4-week avg", "Recovery Flag": "CRITICAL" },
    chunks: [
      { text: "A reactive deload reducing total volume by 40-50% while preserving intensity prevents overtraining syndrome and tendonitis.", q: "0.97", c: "0.989" },
      { text: "CNS recovery requires reducing sets per muscle group to 4-6 sets per week.", q: "0.92", c: "0.952" }
    ],
    output: { status: "success", pipeline: "systemic_deload_protective", recommendation: { focus: "CNS Resensitization Deload", rationale: "Weekly tonnage spiked +38% with avg RPE 9.2 across 5 consecutive days. Triggered deload to prevent non-functional overreaching.", exercises: [{ name: "Back Squat", sets: 2, reps: 5, intensity: "70% 1RM", rpe: 6 }, { name: "Romanian Deadlift", sets: 2, reps: 8, intensity: "65% 1RM", rpe: 6 }], volume_reduction: "-45%", recovery_hours: 48 } }
  }
};

function initSimulator() {
  const tabs = document.querySelectorAll('.sim-tab');
  const statsEl = document.getElementById('sim-stats');
  const chunksEl = document.getElementById('sim-chunks');
  const outputEl = document.getElementById('sim-output');
  if (!tabs.length) return;

  function render(key) {
    const d = scenarios[key];
    statsEl.innerHTML = Object.entries(d.stats).map(([k, v]) =>
      `<div class="sim-row"><span class="sim-key">${k}</span><span class="sim-val">${v}</span></div>`
    ).join('');
    chunksEl.innerHTML = d.chunks.map((c, i) =>
      `<div class="sim-chunk">
        <div class="sim-chunk-head"><span>Chunk #${i + 1}</span><span>Qdrant: <span class="qdrant">${c.q}</span> · Cohere: <span class="cohere">${c.c}</span></span></div>
        <div class="sim-chunk-body">${c.text}</div>
      </div>`
    ).join('');
    outputEl.textContent = JSON.stringify(d.output, null, 2);
  }

  tabs.forEach(tab => {
    tab.addEventListener('click', () => {
      tabs.forEach(t => t.classList.remove('active'));
      tab.classList.add('active');
      render(tab.dataset.sim);
    });
  });

  render('beginner');
}

// ============================================================
// 5. COPY BUTTONS
// ============================================================
function initCopyButtons() {
  document.querySelectorAll('.copy-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const src = document.getElementById(btn.dataset.target);
      if (!src) return;
      navigator.clipboard.writeText(src.innerText.trim()).then(() => {
        const orig = btn.innerHTML;
        btn.classList.add('copied');
        btn.textContent = '✓ Copied!';
        setTimeout(() => { btn.classList.remove('copied'); btn.innerHTML = orig; }, 2000);
      });
    });
  });
}

// ============================================================
// 6. MODAL — fixed close handler
// ============================================================
function initModal() {
  const overlay = document.getElementById('modal');
  const closeBtn = document.getElementById('modal-close');
  const openBtns = [
    document.getElementById('open-modal'),
    document.getElementById('open-modal-summary')
  ].filter(Boolean);
  if (!overlay) return;

  function open() { overlay.classList.add('open'); }
  function close() { overlay.classList.remove('open'); }

  openBtns.forEach(btn => btn.addEventListener('click', open));
  if (closeBtn) closeBtn.addEventListener('click', close);

  // Click outside to close
  overlay.addEventListener('click', (e) => {
    if (e.target === overlay) close();
  });

  // Escape key
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') close();
  });
}
