# Securing EKS Resource Deployment: Integrating OIDC IAM Roles with GitHub Actions

## Overview

This document provides a guide on securing EKS deployments by integrating GitHub Actions with AWS using OpenID Connect (OIDC) for IAM roles. This method avoids the use of long-term AWS credentials, enhancing security and streamlining the CI/CD pipeline for deploying resources to an EKS cluster.

## Prerequisites

1. **AWS Account** with EKS already set up.
2. **GitHub Repository** for hosting your code and GitHub Actions.
3. **AWS CLI** installed and configured.

## Step-by-Step Guide

### 1. Enable OIDC Provider in AWS

1. Open the **IAM Console** in AWS.
2. Navigate to **Identity Providers** under the IAM menu.
3. Add a **new identity provider**, selecting `OpenID Connect (OIDC)`.
4. For the URL, use GitHub’s OIDC URL: `https://token.actions.githubusercontent.com`.

### 2. Create a Role for GitHub Actions

1. Create a **new IAM role** that allows GitHub Actions to assume the role.
2. Select **Web Identity** as the trusted entity.
3. Select the OIDC provider created in the previous step.
4. Attach policies to the role, limiting the permissions as needed (e.g., `AmazonEKSClusterPolicy`, `AmazonEC2ContainerRegistryReadOnly`).

### 3. Configure GitHub Secrets

1. In your GitHub repository, navigate to **Settings** > **Secrets and Variables** > **Actions**.
2. Add the following secrets:
   - `AWS_TERRAFORM_ROLE`: The ARN of the IAM role created.
   - `AWS_REGION`: The region where your EKS cluster is deployed.
   - `AWS_ECR_PUSH_ROLE`: The ARN of the IAM role created for ecr
	


### 4. Set Up GitHub Actions Workflow

In your `.github/workflows/deploy.yml`, configure the workflow to authenticate using OIDC and assume the AWS IAM role:

```yaml
name: Deploy to EKS

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest

    permissions:
      id-token: write
      contents: read

    steps:
      - name: Checkout code
        uses: actions/checkout@v2

      - name: Configure AWS credentials with OIDC
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Deploy to EKS
        run: |
          # Add your deployment steps here
          kubectl apply -f deployment.yaml
