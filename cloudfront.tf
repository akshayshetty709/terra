# CloudFront distribution serving from S3
resource "aws_cloudfront_distribution" "production" {
origin {
    domain_name              = aws_s3_bucket.production.bucket_regional_domain_name
    origin_id                = "s3-origin"
}
 enabled             = true
 default_root_object = "index.html" 

 default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-origin"
    viewer_protocol_policy = "redirect-to-https"  

 forwarded_values {  #taken from aws documentation
      query_string = false

      cookies {
        forward = "none"
      }
    } 
 }
 restrictions {  #taken from oneuptime
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
