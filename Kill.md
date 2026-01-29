Application Description for POC: E-Commerce Microservices System
Build a lightweight e-commerce application with a microservices architecture that demonstrates distributed system patterns. The application should consist of 3-4 interconnected Python services:
Services:
API Gateway Service - Flask/FastAPI based REST API that handles incoming requests and routes them to backend services
Product Catalog Service - Manages product inventory with a simple SQLite database, includes CRUD operations
Order Service - Handles order creation and processing, communicates with Product Catalog to check inventory
Payment Service (optional) - Simulates payment processing with artificial delays
Key Requirements:
Each service should be a separate Python application with its own directory structure
Services communicate via HTTP REST calls (no message queues initially)
Include realistic business logic: inventory checks, order validation, payment simulation with success/failure scenarios
Add some intentional performance bottlenecks (synchronous calls, database queries without connection pooling, no caching)
Include proper error handling and logging using Python's logging module
Each service should have a requirements.txt file
Provide Dockerfiles for each service
Include docker-compose.yml for local orchestration
Provide Kubernetes manifests (deployments, services) for Rancher/Minikube deployment
Application Features:
List products endpoint
Create order endpoint (checks inventory, processes payment)
Get order status endpoint
Simple health check endpoints for each service
Important: The application should be fully functional but completely uninstrumented - no OpenTelemetry, no Prometheus metrics, no distributed tracing, no custom monitoring. This provides a clean baseline for demonstrating how an AI coding agent can add comprehensive instrumentation after the fact.
The app should be simple enough to understand quickly but complex enough to showcase meaningful distributed tracing, metrics collection, and logging instrumentation across multiple services.
