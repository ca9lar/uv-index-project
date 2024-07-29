# UV Index Alert System

This project provides an automated UV index alert system using AWS services and Terraform.

## Architecture Diagram

![Architecture Diagram](path/to/your/diagram.png)

## Description

1. **User Interaction**
   - Users can manually trigger the UV index alert via an API Gateway endpoint.
   - Automated triggering is done by a CloudWatch Event.

2. **AWS Components**
   - **API Gateway**: An endpoint for manually triggering the UV index check.
   - **Lambda Function**: The core logic that fetches the UV index data and publishes alerts.
     - Fetches coordinates (latitude and longitude) for the specified ZIP code using the OpenWeatherMap Geocoding API.
     - Fetches the UV index using the OpenWeatherMap UV Index API.
     - Publishes alerts to an SNS topic based on the UV index level.
   - **CloudWatch Events**: Periodically triggers the Lambda function to check the UV index.
   - **SNS Topic**: Sends alerts to subscribed endpoints (email, SMS, etc.).

3. **Secrets and Configuration**
   - **GitHub Actions**: Automates the deployment process.
     - Fetches secrets (AWS credentials and API key) from GitHub Secrets.
     - Plans and applies the Terraform configuration.
