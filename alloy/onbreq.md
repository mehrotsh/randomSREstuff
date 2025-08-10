GitLab Stories (SRE Team's Perspective)

  Here are the stories that your team would work on to onboard an application team.

  Epic: Onboard [Application Name] to the Observability Platform

  Description: This epic covers all the tasks for the SRE team to onboard the [Application Name] team to the central observability platform.

  ---

  Story 1: Kick-off Onboarding for [Application Name]

  Title: As an SRE, I want to conduct a kick-off meeting with the [Application Name] team to understand their application and observability needs.

  Description: This story involves scheduling and conducting a kick-off meeting with the application team to introduce them to the observability
  platform, discuss the onboarding process, and gather the necessary information to tailor the setup.

  Acceptance Criteria:

   * [ ] A kick-off meeting has been held with the [Application Name] team.
   * [ ] The "Application Onboarding Questionnaire" (see below) has been filled out and reviewed with the application team.
   * [ ] The application team understands the onboarding process and their responsibilities.
   * [ ] The next steps and timelines have been agreed upon.

  ---

  Story 2: Assist [Application Name] Team with OpenTelemetry Instrumentation

  Title: As an SRE, I want to assist the [Application Name] team with instrumenting their application with OpenTelemetry.

  Description: This story covers the SRE team's role in providing guidance, best practices, and support to the application team as they instrument
  their application with OpenTelemetry.

  Acceptance Criteria:

   * [ ] The application team has been provided with the relevant documentation and examples for OpenTelemetry instrumentation.
   * [ ] The SRE team has reviewed the application team's instrumentation approach and provided feedback.
   * [ ] The application is successfully generating traces, metrics, and logs in a development environment.

  ---

  Story 3: Configure and Deploy Grafana Alloy Agent for [Application Name]

  Title: As an SRE, I want to configure and deploy the Grafana Alloy agent for the [Application Name] team.

  Description: This story involves creating a tailored configuration for the Grafana Alloy agent based on the information gathered from the
  application team, and then deploying the agent to their Kubernetes cluster.

  Acceptance Criteria:

   * [ ] A dedicated values.yaml file has been created for the [Application Name] team's Alloy agent.
   * [ ] The Alloy agent is configured to scrape telemetry from the application.
   * [ ] The agent is configured to send data to the central observability cluster with the correct metadata.
   * [ ] The agent has been successfully deployed to the application's Kubernetes cluster.
   * [ ] The configuration is stored in a central repository and managed as code.

  ---

  Story 4: Create Initial Grafana Dashboards for [Application Name]

  Title: As an SRE, I want to create a set of initial Grafana dashboards for the [Application Name] team.

  Description: This story covers the creation of a set of pre-built Grafana dashboards to provide the application team with immediate visibility into
  their application's health and performance.

  Acceptance Criteria:

   * [ ] A dashboard has been created to visualize the application's key metrics (e.g., request rate, error rate, latency).
   * [ ] A dashboard has been created for viewing the application's logs.
   * [ ] The dashboards have been shared with the [Application Name] team.
   * [ ] The application team has been shown how to use the dashboards.

  ---

  Information to Collect from Application Teams

  To tailor the observability setup for each application, you should collect the following information.

  Application Onboarding Questionnaire:

   1. Application Information:
       * Application Name:
       * Brief Description of the Application's Purpose:
       * Source Code Repository:
       * Programming Language(s) and Framework(s):

   2. Architecture:
       * Please provide a high-level architecture diagram of your application.
       * What are the key components and services of your application?
       * What are the key dependencies of your application (e.g., databases, caches, external APIs)?

   3. Key Business Transactions:
       * What are the most critical user journeys or business transactions in your application? (e.g., user login, product purchase, data processing
         pipeline)

   4. Service Level Objectives (SLOs):
       * What are the key performance indicators (KPIs) for your application? (e.g., latency, error rate, uptime)
       * Do you have any existing SLOs for your application? If so, what are they?

   5. Logging:
       * What are the most important log messages to monitor for? (e.g., errors, warnings, key business events)
       * What is the format of your application's logs? (e.g., JSON, plain text)

   6. Alerting:
       * What are the key conditions that should trigger an alert? (e.g., high error rate, high latency, service down)
       * Who should be notified when an alert is triggered? (e.g., on-call engineer, development team)

   7. Team Information:
       * Application Team Name:
       * Team Members and Roles:
       * On-call Contact Information:

  ---

  Recommended Way to Collect Information Using GitLab

  Using GitLab is an excellent way to manage the onboarding process for multiple teams. Here's a recommended approach:

   1. Create a GitLab Issue Template:
       * Create a new file in your GitLab project under .gitlab/issue_templates/application_onboarding.md.
       * Paste the "Application Onboarding Questionnaire" into this file.
       * Now, when a new issue is created in your project, the application team can select the application_onboarding template, and the questionnaire
         will be pre-filled in the issue description.

   2. Use GitLab Labels:
       * Create a set of labels to track the status of the onboarding process. For example:
           * onboarding-request: For new onboarding requests.
           * onboarding-in-progress: For onboarding that is actively being worked on.
           * onboarding-blocked: For when the SRE team is waiting for information or action from the application team.
           * onboarding-done: For completed onboardings.

   3. Use GitLab Epics:
       * For each application team that needs to be onboarded, create an epic.
       * All the onboarding stories for that team can be grouped under this epic. This provides a high-level view of the onboarding progress for each
         team.
