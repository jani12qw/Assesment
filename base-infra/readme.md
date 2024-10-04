# CloudFormation OIDC and S3 Setup

This CloudFormation template automates the creation of an OIDC provider for GitHub, assigns roles with AWS managed policies, and creates an S3 bucket. It allows GitHub Actions to authenticate with AWS, enabling secure deployments and ECR image pushes.

## Features
- **OIDC Provider**: Creates an OIDC provider for GitHub Actions.
- **IAM Roles**: Two roles are created:
  - One for general access with `AdministratorAccess`.
  - One for pushing images to Amazon ECR with `AmazonEC2ContainerRegistryPowerUser`.
- **S3 Bucket**: A new S3 bucket is created with versioning enabled.

## Parameters
- **S3BucketName**: Name of the S3 bucket (default: `my-github-oidc-bucket`).
- **GitHubOrganization**: Your GitHub organization name.
- **GitHubRepo**: Your GitHub repository name.
- **GitHubBranch**: The branch used for OIDC (default: `main`).

## Deployment Steps
1. **Open the AWS Management Console**.
2. Navigate to **CloudFormation**.
3. Choose **Create Stack** > **With new resources (standard)**.
4. Upload the CloudFormation template file.
5. Provide the necessary parameters:
   - Enter your GitHub organization name, repository name, and desired S3 bucket name.
6. Click **Next**, configure stack options, and review.
7. Click **Create Stack**.

Once the stack is created successfully, you will find the ARNs of the OIDC provider and IAM roles in the Outputs section.

## Important Notes
- Ensure that your AWS account has the necessary permissions to create IAM roles and S3 buckets.
- Adjust the managed policies as per your security requirements.
