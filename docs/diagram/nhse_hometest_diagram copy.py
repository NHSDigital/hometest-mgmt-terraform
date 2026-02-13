#!/usr/bin/env python3
"""
NHSE Home Testing AWS Infrastructure Diagram Generator
Using mingrammer/diagrams library to create visual infrastructure representation
Based on notes from Digital Health Check project
"""

from diagrams import Diagram, Cluster, Edge
from diagrams.aws.compute import Lambda, Fargate
from diagrams.aws.network import CloudFront, VPC, NATGateway, DirectConnect
from diagrams.aws.storage import S3
from diagrams.aws.security import IAM, KMS
from diagrams.aws.management import Cloudwatch, Organizations
from diagrams.aws.general import Users
from diagrams.onprem.vcs import Github
from diagrams.onprem.ci import GithubActions
from diagrams.onprem.iac import Terraform
from diagrams.aws.integration import APIGateway

# Set diagram configuration
graph_attr = {
    "fontsize": "14",
    "bgcolor": "white",
    "dpi": "300",
    "size": "18,14",
    "rankdir": "TB",
    "concentrate": "true",
    "pad": "0.5"
}

node_attr = {
    "fontsize": "10",
    "style": "rounded,filled",
    "fillcolor": "lightblue",
    "margin": "0.1"
}

with Diagram("NHSE Home Testing - AWS Infrastructure",
             show=False,
             filename="nhse_hometest_infrastructure",
             graph_attr=graph_attr,
             node_attr=node_attr,
             direction="TB"):

    # External Users
    with Cluster("External Users"):
        users = Users("~3 Million Users/Year\n(Digital Health Check)")

    # CI/CD Pipeline
    with Cluster("CI/CD Pipeline"):
        github = Github("GitHub\n(Source Control)")
        github_actions = GithubActions("GitHub Actions\n(CI/CD Pipelines)")
        cdk = Terraform("AWS CDK (~80%)\n+ tf-scaffold")

    github >> github_actions >> cdk

    # NHS Network
    with Cluster("NHS Network (HSCN/N3)"):
        hscn = DirectConnect("HSCN\n(Private NHS Network)")
        nat_gw = NATGateway("NAT Gateway\n(Outbound Only)")

    # Management/Shared Account
    with Cluster("AWS Management Account\n(Shared Services)"):
        organizations = Organizations("AWS Organizations")
        iam_shared = IAM("SSO & Permission Sets")
        
    # Virginia Region (CloudFront only)
    with Cluster("us-east-1 (Virginia)"):
        cloudfront = CloudFront("CloudFront\n(CDN)")

    # London Region (Primary - Everything)
    with Cluster("eu-west-2 (London) - Primary"):
        
        # Development Environment
        with Cluster("Dev Account"):
            dev_vpc = VPC("Dev VPC")
            dev_lambda = Lambda("Lambda Functions")
            dev_api = APIGateway("API Gateway")
            dev_s3 = S3("S3 Storage")
            dev_cw = Cloudwatch("CloudWatch\n(90 days - Prod)")
            
            dev_api >> dev_lambda >> dev_s3

        # Staging Environment
        with Cluster("Staging Account"):
            staging_vpc = VPC("Staging VPC")
            staging_lambda = Lambda("Lambda Functions")
            staging_api = APIGateway("API Gateway")
            staging_s3 = S3("S3 Storage")
            
            staging_api >> staging_lambda >> staging_s3

        # Production Environment
        with Cluster("Prod Account"):
            prod_vpc = VPC("Prod VPC")
            prod_lambda = Lambda("Lambda Functions")
            prod_api = APIGateway("API Gateway")
            prod_s3 = S3("S3 Storage")
            prod_kms = KMS("KMS")
            prod_cw = Cloudwatch("CloudWatch\n(90 days retention)")
            
            prod_api >> prod_lambda >> prod_s3
            prod_lambda >> prod_kms

    # Ireland Region (Select Services)
    with Cluster("eu-west-1 (Ireland)"):
        ireland_s3 = S3("Backup/DR\n(Select Services)")

    # Security & Support Teams
    with Cluster("Operations"):
        csoc = Users("CSOC\n(Security Team)")
        itoc = Users("ITOC\n(Support - Splunk)")

    # Connections
    users >> cloudfront >> prod_api
    
    # HSCN Connection
    hscn >> nat_gw >> prod_vpc
    
    # Management connections
    organizations >> Edge(label="Account Management") >> dev_vpc
    organizations >> Edge(label="Account Management") >> staging_vpc
    organizations >> Edge(label="Account Management") >> prod_vpc
    
    # CI/CD to environments (manual promotion)
    cdk >> Edge(label="Deploy") >> dev_vpc
    cdk >> Edge(label="Manual Promotion") >> staging_vpc
    cdk >> Edge(label="Manual Promotion") >> prod_vpc
    
    # Monitoring
    prod_cw >> csoc
    prod_cw >> itoc
    
    # DR/Backup
    prod_s3 >> Edge(label="Backup (30+ days)") >> ireland_s3
