# 100 Days of MLOps

A structured, hands-on roadmap to learn MLOps from scratch. One task per day, 12 domains, building up to a full production ML system.

## Repo layout

- [`days/`](days/) — one directory per day, with the lab README, walkthrough, and reference files.
- [`notes/`](notes/) — cross-cutting concepts (Python packaging, Jinja2, pre-commit, etc.) that span multiple days.
- [`projects/`](projects/) — real-world use cases built alongside the daily labs; longer-arc work that synthesises multiple days into something that does a thing. See [`projects/README.md`](projects/README.md).
- [`BACKLOG.md`](BACKLOG.md) — outstanding work tracked at the repo root.

## Companion study resources

External courses that cover overlapping ground. Not prerequisites — use them as conceptual primers before a domain, or as alternative explanations when something isn't clicking.

| Resource | Style | Best used for |
|---|---|---|
| [Gourav Shah — Ultimate MLOps Bootcamp](https://schoolofdevops.com/programs/mlops-bootcamp/) ([Udemy](https://www.udemy.com/course/devops-to-mlops-bootcamp/)) | Project-driven (one regression project, end-to-end on K8s) | Deploy/runtime side: Docker, K8s, HPA/KEDA, ArgoCD, Prometheus/Grafana (Domains 6, 8, 9, 11) |
| [Made With ML — Goku Mohandas](https://madewithml.com/courses/mlops/) | Project-driven (BERT fine-tuning, distributed training) | GPU/distributed concerns, modern NLP ops — closer shape to a homelab LLM capstone |
| [DataCamp — MLOps Fundamentals](https://www.datacamp.com/tracks/mlops-fundamentals) + [ML Engineer track](https://www.datacamp.com/tracks/machine-learning-engineer) | In-browser exercises, concept-heavy | Quick conceptual primers before MLflow (Domain 3), monitoring (Domain 8), CI/CD (Domain 9) |

This roadmap is broader than any single one of them — it explicitly covers DVC, Feast, Great Expectations, Argo Workflows, and HPO that the others skip — but they go deeper on the parts they pick.

---

## Domain 1: ML Project Setup (Days 1–9)

- [x] **Day 1** — Create a Python Virtual Environment
- [x] **Day 2** — Launch a Jupyter Notebook
- [x] **Day 3** — Set Up a Project with uv
- [x] **Day 4** — Organize an ML Project Structure
- [x] **Day 5** — Automate Tasks with a Makefile
- [x] **Day 6** — Add Code Quality Tools (ruff, mypy)
- [x] **Day 7** — Package a Python ML Project
- [x] **Day 8** — Set Up Pre-commit Hooks
- [x] **Day 9** — Scaffold a Project with Cookiecutter

## Domain 2: DVC — Data Version Control (Days 10–19)

- [x] **Day 10** — Install and Initialize DVC
- [ ] **Day 11** — Track a Dataset with DVC
- [ ] **Day 12** — Configure DVC Remote Storage
- [ ] **Day 13** — Pull Data from Remote
- [ ] **Day 14** — Build a DVC Pipeline
- [ ] **Day 15** — Parameterize a DVC Pipeline
- [ ] **Day 16** — Track Metrics with DVC
- [ ] **Day 17** — Run DVC Experiments
- [ ] **Day 18** — Version Data and Models Together
- [ ] **Day 19** — Build a Full DVC Pipeline (End-to-End)

## Domain 3: MLflow — Experiment Tracking (Days 20–30)

- [ ] **Day 20** — Install and Configure MLflow
- [ ] **Day 21** — Log Your First Experiment
- [ ] **Day 22** — Organize Experiments and Runs
- [ ] **Day 23** — Search and Query Runs
- [ ] **Day 24** — Enable Autologging
- [ ] **Day 25** — Register a Model in the Model Registry
- [ ] **Day 26** — Compare Runs in the MLflow UI
- [ ] **Day 27** — Load a Model from the Registry
- [ ] **Day 28** — Fix a Broken ML Project with MLflow
- [ ] **Day 29** — Configure a Remote MLflow Server
- [ ] **Day 30** — End-to-End ML Lifecycle with MLflow

## Domain 4: Model Training (Days 31–40)

- [ ] **Day 31** — Train a Model with scikit-learn
- [ ] **Day 32** — Configure Training with YAML
- [ ] **Day 33** — Evaluate Model Performance
- [ ] **Day 34** — Implement Cross-Validation
- [ ] **Day 35** — Hyperparameter Tuning with Optuna
- [ ] **Day 36** — AutoML with FLAML
- [ ] **Day 37** — Parallel Training with joblib
- [ ] **Day 38** — Build a Modular Training Pipeline
- [ ] **Day 39** — GPU Training with PyTorch
- [ ] **Day 40** — Production Training Pipeline

## Domain 5: Feature Store & Data Quality (Days 41–49)

- [ ] **Day 41** — Set Up Feast Feature Store
- [ ] **Day 42** — Define and Serve Features with Feast
- [ ] **Day 43** — Online vs Offline Features in Feast
- [ ] **Day 44** — Manage Secrets with HashiCorp Vault
- [ ] **Day 45** — Integrate Vault with ML Pipelines
- [ ] **Day 46** — Data Validation with Great Expectations
- [ ] **Day 47** — Build Expectation Suites
- [ ] **Day 48** — Great Expectations in a Pipeline
- [ ] **Day 49** — Capstone: Feature Store + Data Quality

## Domain 6: Docker for ML (Days 50–56)

- [ ] **Day 50** — Build a Docker Training Image
- [ ] **Day 51** — Multi-Stage Docker Builds
- [ ] **Day 52** — Docker Compose for ML Services
- [ ] **Day 53** — GPU Support in Docker
- [ ] **Day 54** — Push Images to a Container Registry
- [ ] **Day 55** — Health Checks for ML Containers
- [ ] **Day 56** — CI Docker Builds

## Domain 7: Model Serving (Days 57–66)

- [ ] **Day 57** — Serve a Model with Flask
- [ ] **Day 58** — Serve a Model with FastAPI
- [ ] **Day 59** — Batch Prediction Endpoint
- [ ] **Day 60** — Serve with BentoML
- [ ] **Day 61** — Containerize a Model Server
- [ ] **Day 62** — A/B Testing for Models
- [ ] **Day 63** — Async Batch Inference
- [ ] **Day 64** — API Gateway for Model Serving
- [ ] **Day 65** — Canary Deployment
- [ ] **Day 66** — Production Model Serving with Docker Compose

## Domain 8: Monitoring (Days 67–75)

- [ ] **Day 67** — Set Up Prometheus and Grafana
- [ ] **Day 68** — Evidently Data Quality Reports
- [ ] **Day 69** — Evidently Data Quality Tests
- [ ] **Day 70** — Evidently Model Quality Monitoring
- [ ] **Day 71** — Build an Evidently Dashboard
- [ ] **Day 72** — Drift Detection Alerts
- [ ] **Day 73** — Automated Model Retraining
- [ ] **Day 74** — Business Metrics Monitoring
- [ ] **Day 75** — End-to-End Monitoring Pipeline

## Domain 9: CI/CD for ML (Days 76–84)

- [ ] **Day 76** — Lint and Test ML Code in CI
- [ ] **Day 77** — Data Validation in CI
- [ ] **Day 78** — Model Validation in CI
- [ ] **Day 79** — CML — Continuous Machine Learning
- [ ] **Day 80** — Automated Model Registration
- [ ] **Day 81** — Automated Model Deployment
- [ ] **Day 82** — End-to-End ML CI/CD Pipeline
- [ ] **Day 83** — Rollback Strategies for ML
- [ ] **Day 84** — Multi-Environment Promotion

## Domain 10: Orchestration (Days 85–91)

- [ ] **Day 85** — Install Argo Workflows
- [ ] **Day 86** — Build a Training Workflow
- [ ] **Day 87** — Parameters and Branching in Argo
- [ ] **Day 88** — Orchestrate with Prefect
- [ ] **Day 89** — Fan-Out Workflows
- [ ] **Day 90** — CronWorkflow for Scheduled Training
- [ ] **Day 91** — Production Orchestration Pipeline

## Domain 11: Kubernetes (Days 92–96)

- [ ] **Day 92** — Deploy a Model on Kubernetes
- [ ] **Day 93** — Horizontal Pod Autoscaling (HPA)
- [ ] **Day 94** — Serve Models with KServe
- [ ] **Day 95** — ML Pipelines with Kubeflow
- [ ] **Day 96** — GitOps with ArgoCD

## Domain 12: Capstone (Days 97–100)

- [ ] **Day 97** — Train, Register, and Serve a Model
- [ ] **Day 98** — Monitoring and Auto-Retraining
- [ ] **Day 99** — Argo Orchestration for Full Pipeline
- [ ] **Day 100** — Observability with Prometheus and Grafana

---

Progress: 0 / 100 days complete
