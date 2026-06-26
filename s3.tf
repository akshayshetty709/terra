# Complete production-ready S3 bucket
resource "aws_s3_bucket" "production" {
  bucket = "assesment-s3-210795"

  tags = {
    Name        = "Production Data"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_versioning" "production" {
  bucket = aws_s3_bucket.production.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "production" {
  bucket                  = aws_s3_bucket.production.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_website_configuration" "production" {
  bucket = aws_s3_bucket.production.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}
