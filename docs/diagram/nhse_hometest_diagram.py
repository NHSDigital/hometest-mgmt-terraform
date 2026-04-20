#!/usr/bin/env python3
"""
NHSE Home Testing Application Architecture Diagram
Using mingrammer/diagrams library to create visual infrastructure representation
Based on the NHS Home Testing service flow

Best Practices:
- Color-coded edges for different flow types
- Labels on edges for clarity
- Grouped clusters by domain
- Consistent styling
"""

from diagrams import Diagram, Cluster, Edge
from diagrams.aws.compute import Lambda
from diagrams.aws.integration import SQS
from diagrams.aws.database import Dynamodb
from diagrams.aws.security import SecretsManager
from diagrams.aws.storage import S3
from diagrams.aws.network import APIGateway
from diagrams.onprem.client import Client
from diagrams.custom import Custom

# Edge styles for different flow types
USER_FLOW = Edge(color="darkgreen", style="bold", label="user request")
API_FLOW = Edge(color="blue", style="bold")
ORDER_FLOW = Edge(color="orange", style="bold")
RESULT_FLOW = Edge(color="purple", style="bold")
DATA_FLOW = Edge(color="gray", style="dashed")
QUEUE_FLOW = Edge(color="brown", style="bold", label="async")
EXTERNAL_FLOW = Edge(color="red", style="bold", label="external")
AUTH_FLOW = Edge(color="teal", style="dotted", label="auth")
NOTIFY_FLOW = Edge(color="green", style="bold", label="notify")

# Set diagram configuration
graph_attr = {
    "fontsize": "16",
    "bgcolor": "white",
    "dpi": "300",
    "size": "24,18",
    "rankdir": "LR",
    "splines": "polyline",
    "pad": "0.8",
    "nodesep": "0.6",
    "ranksep": "1.0"
}

node_attr = {
    "fontsize": "11",
    "margin": "0.2"
}

cluster_attr = {
    "fontsize": "14",
    "bgcolor": "lightgrey"
}

with Diagram("NHSE Home Testing - Application Architecture",
             show=False,
             filename="nhse_hometest_architecture",
             graph_attr=graph_attr,
             node_attr=node_attr,
             direction="LR"):

    # ===== USER ACCESS LAYER =====
    with Cluster("User Access Layer", graph_attr={"bgcolor": "#e8f5e9"}):
        nhs_app = Client("NHS App")
        web_ui = Client("Web UI")
        nhs_login = Client("NHS Login\n(Authentication)")

    # ===== API GATEWAY =====
    with Cluster("API Management", graph_attr={"bgcolor": "#e3f2fd"}):
        apim = APIGateway("APIM\n(API Gateway)")

    # ===== PROCESSING LAYER =====
    with Cluster("Processing Layer", graph_attr={"bgcolor": "#fafafa"}):

        # ===== ORDER PROCESSING DOMAIN =====
        with Cluster("Order Processing Domain", graph_attr={"bgcolor": "#fff3e0"}):
            test_info_service = Lambda("Test Info\nService")
            order_event_service = Lambda("Order Event\nService")
            order_service = Lambda("Order\nService")
            order_router = Lambda("Order\nRouter")
            order_eligibility_service = Lambda("Order Eligibility\nService")
            order_queue = SQS("Order Queue")
            routing_service = Lambda("Routing\nService")

        # ===== RESULT PROCESSING DOMAIN =====
        with Cluster("Result Processing Domain", graph_attr={"bgcolor": "#f3e5f5"}):
            result_service = Lambda("Result\nService")
            result_queue = SQS("Result Queue")
            result_router = Lambda("Result\nRouter")
            view_result_service = Lambda("View Result\nService")

        # ===== NOTIFICATION DOMAIN =====
        with Cluster("Notification Domain", graph_attr={"bgcolor": "#e8f5e9"}):
            notify_service = Lambda("Notify\nService")
            nhs_notify = Client("NHS Notify\n(Gov.UK Notify)")

        # ===== EXTERNAL INTEGRATIONS =====
        with Cluster("External Partners", graph_attr={"bgcolor": "#ffebee"}):
            test_suppliers = Client("Test Suppliers\n(Third Party)")

    # ===== DATA LAYER =====
    with Cluster("Data Layer", graph_attr={"bgcolor": "#fce4ec"}):
        home_test_data_store = Dynamodb("Home Test\nData Store")
        secrets_manager = SecretsManager("Secrets\nManager")
        supplier_config = S3("Supplier\nConfig")

    # ===== CONNECTIONS =====
    # User Entry Flow
    nhs_app >> Edge(color="darkgreen", style="bold") >> web_ui
    web_ui >> Edge(color="darkgreen", style="bold", label="request") >> apim
    web_ui >> Edge(color="teal", style="dotted", label="authenticate") >> nhs_login

    # APIM to Order Services (Blue - API calls)
    apim >> Edge(color="blue", label="get info") >> test_info_service
    apim >> Edge(color="blue", label="track order") >> order_event_service
    apim >> Edge(color="blue", label="place order") >> order_service
    apim >> Edge(color="blue", label="check eligibility") >> order_eligibility_service

    # APIM to Result/Notify Services
    apim >> Edge(color="purple", label="view result") >> view_result_service
    apim >> Edge(color="green", label="send notification") >> notify_service

    # Order Processing Flow (Orange)
    order_service >> Edge(color="orange", style="bold", label="queue order") >> order_queue
    order_queue >> Edge(color="orange", style="bold", label="process") >> order_router
    order_router >> Edge(color="orange", style="dashed", label="get routing") >> routing_service
    order_router >> Edge(color="red", style="bold", label="fulfill order") >> test_suppliers

    # Data Store Connections (Pink/Magenta for visibility)
    order_event_service >> Edge(color="#d81b60", style="bold", label="read/write") >> home_test_data_store
    order_queue >> Edge(color="#d81b60", style="bold", label="get secrets") >> secrets_manager
    secrets_manager >> Edge(color="#d81b60", style="bold", label="config") >> supplier_config
    test_info_service >> Edge(color="#d81b60", style="bold", label="read") >> home_test_data_store

    # External Integrations (Red)
    order_eligibility_service >> Edge(color="red", style="bold", label="check stock") >> test_suppliers

    # Result Processing Flow (Purple)
    # Supplier calls Result Service to submit test results
    test_suppliers >> Edge(color="red", style="bold", label="submit result") >> result_service
    result_service >> Edge(color="purple", style="bold", label="queue result") >> result_queue
    result_queue >> Edge(color="purple", style="bold", label="process") >> result_router
    result_router >> Edge(color="#d81b60", style="bold", label="save result status") >> home_test_data_store
    result_router >> Edge(color="green", style="bold", label="trigger notify") >> notify_service

    # View Result Service (called by Web UI, fetches from supplier)
    view_result_service >> Edge(color="red", style="bold", label="fetch result") >> test_suppliers

    # Notification Flow (Green)
    notify_service >> Edge(color="green", style="bold", label="send SMS/email") >> nhs_notify
