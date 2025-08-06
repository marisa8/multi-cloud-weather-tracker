# AWS provider
provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = "us-east-1"
}

# Azure provider
provider "azurerm" {
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
  features {}
}

# Define an S3 bucket for static website hosting
resource "aws_s3_bucket" "weather_app" {
  bucket = "weather-tracker-app-bucket-marisa-345382"  # Use a globally unique name

  website {
    index_document = "index.html"
    error_document = "error.html"
  }

  # Set bucket ownership controls
  lifecycle {
    prevent_destroy = true  # Prevent accidental deletion
  }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket                  = aws_s3_bucket.weather_app.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Upload website files to the S3 bucket
resource "aws_s3_object" "website_index" {
  bucket = aws_s3_bucket.weather_app.id
  key    = "index.html"
  source = "website/index.html"
  content_type = "text/html"
}

resource "aws_s3_object" "website_style" {
  bucket = aws_s3_bucket.weather_app.id
  key    = "styles.css"
  source = "website/styles.css"
  content_type = "text/css"
}

resource "aws_s3_object" "website_script" {
  bucket = aws_s3_bucket.weather_app.id
  key    = "script.js"
  source = "website/script.js"
  content_type = "application/javascript"
}

# Upload assets (images) to the S3 bucket
resource "aws_s3_object" "website_assets" {
  for_each = fileset("website/assets", "*")
  bucket   = aws_s3_bucket.weather_app.id
  key      = "assets/${each.value}"
  source   = "website/assets/${each.value}"
}

# Add a bucket policy to allow public read access
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.weather_app.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "arn:aws:s3:::${aws_s3_bucket.weather_app.id}/*"
      },
      {
        Sid       = "CloudFrontLogsWrite",
        Effect    = "Allow",
        Principal = {
          Service = "cloudfront.amazonaws.com"
        },
        Action    = "s3:PutObject",
        Resource  = "arn:aws:s3:::${aws_s3_bucket.weather_app.id}/cloudfront-logs/*"
      }
    ]
  })
}

# Define Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-static-website"
  location = "East US"
}

# Define Storage Account with Static Website
resource "azurerm_storage_account" "storage" {
  name                     = "marisastorage345382"
  resource_group_name       = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier              = "Standard"
  account_replication_type = "LRS"
  account_kind              = "StorageV2"

  static_website {
    index_document = "index.html"
  }
}

# Upload index.html
resource "azurerm_storage_blob" "index_html" {
  name                   = "index.html"
  storage_account_name   = azurerm_storage_account.storage.name
  storage_container_name = "$web"  # Static website container
  type                   = "Block"
  content_type           = "text/html"
  source                 = "website/index.html"  # Path to local file
}

# Upload styles.css
resource "azurerm_storage_blob" "styles_css" {
  name                   = "styles.css"
  storage_account_name   = azurerm_storage_account.storage.name
  storage_container_name = "$web"
  type                   = "Block"
  content_type           = "text/css"
  source                 = "website/styles.css"  # Path to local file
}

# Upload script.js
resource "azurerm_storage_blob" "scripts_js" {
  name                   = "script.js"
  storage_account_name   = azurerm_storage_account.storage.name
  storage_container_name = "$web"
  type                   = "Block"
  content_type           = "application/javascript"
  source                 = "website/script.js"  # Path to local file
}

# Upload images
resource "azurerm_storage_blob" "website_assets" {
  for_each = fileset("website/assets", "*")
  name                   = "assets/${each.value}"
  storage_account_name   = azurerm_storage_account.storage.name
  storage_container_name = "$web"
  type                   = "Block"
  source                 = "website/assets/${each.value}"  # Path to local file
}