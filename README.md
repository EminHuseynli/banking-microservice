# Banking Microservices

A distributed banking system built with Spring Boot and Spring Cloud, migrated from a monolithic architecture using the Strangler Fig pattern. This project is the microservice evolution of banking-monolith and serves as the practical case study of an MSc thesis on business continuity during architectural transitions.

## Overview

It is a banking backend. Users register and log in. Authentication is JWT-based; the token carries the user identity through every request. Once authenticated, a user can open a checking or savings account. They can have multiple accounts. Each account has a balance, and only active accounts can be used for transactions. From there, three core operations are available. A user can deposit money into an account, increasing the balance. They can withdraw, which checks whether the balance is sufficient and rejects the request if not. And they can transfer between two of their own accounts, money leaves one and arrives in the other atomically, both changes happen in a single database transaction, so there is no state where one side is updated, and the other is not. Every one of these operations, deposit, withdrawal, and transfer, automatically generates a notification. This happens asynchronously through RabbitMQ, so the user gets their transaction response immediately without waiting for the notification to be processed. The notification service picks it up in the background and stores it. Users can then retrieve their notification history. Users can also view the full history of transactions on any of their accounts, filterable by date range. Everything is secured end-to-end. The gateway validates the JWT on every request, and the user never touches another person's accounts. The user identity is extracted from the token, not trusted from the request body.

## Tech stack and Architecture
This project is built on **Java 17** and **Spring Boot 3.5**, with **Spring Cloud Gateway** handling all incoming traffic and OpenFeign managing service-to-service communication. 
Authentication is stateless, powered by **JWT and Spring Security**. Each service persists its own data in a dedicated PostgreSQL database via Spring Data JPA. 
Asynchronous messaging between services is handled by **RabbitMQ with Spring AMQP**. 
Fault tolerance is provided by **Resilience4j** circuit breaker, while observability is built on **Micrometer, Prometheus, and Grafana**. 
The entire system is containerized with Docker and orchestrated via **Docker Swarm**, with **Nginx** acting as the load balancer and blue-green traffic switch.   

<img width="1920" height="1080" alt="Screenshot (165)" src="https://github.com/user-attachments/assets/b5b9371c-d8b0-4b6d-84c3-812986bae20f" />


The monolith was not rewritten from scratch, it was strangled. Each module was extracted into an independent service one by one, while the system kept running without interruption. Blue-green deployment ensured that at every step, a stable version was always live and traffic could be switched instantly if anything went wrong. The final blow came when the databases were separated, each service claiming ownership of its own schema. At that point, the monolith had nothing left to own. It was removed from the same repository it once dominated.

## RabbitMQ
When the notification service goes down, the messages published by the transaction service do not disappear. This is because RabbitMQ acts as a durable middleman between the two services, the transaction service does not care whether the notification service is alive or not. The transaction service finishes processing a deposit, withdrawal, or transfer. Before returning a response to the client, it publishes a notification event to a RabbitMQ exchange. This is fire-and-forget, the transaction service does not wait for anyone to consume it. The queue is declared as durable. This means RabbitMQ writes the message to disk, not just memory. Even if RabbitMQ itself restarts, the message survives. Notification service never sent an acknowledgment, RabbitMQ knows the message was not processed. It does not discard it. It holds it in the queue indefinitely, waiting for a consumer to come back.

<img width="1100" height="187" alt="image" src="https://github.com/user-attachments/assets/c47d9ddb-93e6-4236-ad92-5c4edcffb4c9" />

<img width="1100" height="165" alt="image" src="https://github.com/user-attachments/assets/3b15c6f2-cb5c-4845-8f34-85790b55cf2b" />

<img width="1100" height="270" alt="image" src="https://github.com/user-attachments/assets/6229858b-a52a-425d-9e51-37ac4bcf634f" />

The notification service reconnects to RabbitMQ and begins consuming from where it left off. The notification service picks up the waiting message, processes it, persists the notification to its own database, and sends an acknowledgment back to RabbitMQ. Only at this point does RabbitMQ remove the message from the queue. The end user's transaction was recorded, the notification was eventually delivered, and nothing was lost, despite the service being completely offline during steps 3 through 5. The two services never needed to be alive at the same time.

<img width="1146" height="151" alt="image" src="https://github.com/user-attachments/assets/d3dbfa43-e858-455a-8ed6-73b3aaa9770f" />

<img width="1146" height="303" alt="image" src="https://github.com/user-attachments/assets/2956155c-704c-46f9-8d90-ed0c9b513fc9" />


## Circuit Breaker
When the account service goes down, the transaction service does not go down with it. This is the entire point of the circuit breaker. 

<img width="1116" height="227" alt="image" src="https://github.com/user-attachments/assets/aad51763-c8b1-4357-878b-23e6d15493e8" />

The container crashes or becomes unreachable. The transaction service has no direct knowledge of this yet it only finds out when it tries to call it. The transaction service attempts to reach the account service via Feign. The calls start timing out or returning connection errors. Resilience4j is watching. It counts each failure against a sliding window of 10 calls. Once more than 50% of calls in the sliding window fail, Resilience4j makes a decision: the account service is not healthy. The circuit trips from CLOSED to OPEN. This is the critical moment. The transaction service stops attempting to reach the account service entirely. It does not wait for timeouts. It does not queue up requests. The moment a new request comes in, Resilience4j intercepts it before it even leaves the transaction service and immediately triggers the fallback. The circuit stays open for 10 seconds. During this window, the transaction service is completely shielded from the dead dependency. No threads are wasted, no resources are consumed trying to reach something that is not there. 

<img width="1646" height="329" alt="image" src="https://github.com/user-attachments/assets/15693f20-3b1b-40f9-99b0-0a5a5a60f151" />
<img width="1192" height="233" alt="image" src="https://github.com/user-attachments/assets/07c81692-6065-4270-b7c1-edf889d17f68" />

You start the account service back up and wait for the next HALF-OPEN window. This time the probe succeeds. Then another. Then one more. All three pass. The circuit closes. The health endpoint shows UP. Everything returns to normal — and the transaction service was never touched throughout any of it.

<img width="1486" height="257" alt="image" src="https://github.com/user-attachments/assets/5b1b07a2-fd89-4ecf-bae4-583815711bfe" />
<img width="1486" height="627" alt="image" src="https://github.com/user-attachments/assets/a883e947-9561-43a7-a44c-93b9f45538f3" />


## Prometheus and Grafana

Every service exposes its own metrics through the Actuator Prometheus endpoint. Prometheus scrapes all of them on a five second interval — api-gateway, user-service, account-service, transaction-service, notification-service, each one separately. This means at any given moment you can open Prometheus and query exactly what is happening inside a single service without any noise from the others. Request counts, response times, JVM memory, active connections, all isolated, all live.   

<img width="1847" height="836" alt="image" src="https://github.com/user-attachments/assets/19409e60-2760-434f-b123-6668d8090353" />

Grafana sits on top of this and makes it visual. Each service gets its own panel. You can see at a glance which ones are healthy, which are under load, and which are struggling. CPU and memory usage, HTTP request rates, error rates, everything broken down by service. But the most telling part is the circuit breaker panel. When you stop the account service and start sending requests, you watch the failure rate climb in real time on the graph. The moment it crosses the threshold, the circuit state changes, you see it flip from CLOSED to OPEN right there on the dashboard. During the HALF-OPEN window you can see the probe calls as a brief dip in traffic. When the account service recovers and the circuit closes, the panel reflects that too, immediately.
Nothing is hidden. Every state transition that Resilience4j goes through internally becomes a visible event on the Grafana dashboard, not inferred, not estimated, but directly measured and displayed.

<img width="1850" height="830" alt="image" src="https://github.com/user-attachments/assets/ea844f06-af5c-479a-8132-cb978857009d" />


