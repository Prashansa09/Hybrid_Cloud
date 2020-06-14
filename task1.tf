provider "aws" {
  version = "~> 2.0"
  region  = "us-east-1"
}

resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16"
}
resource "aws_security_group" "allow_tls" {
	name= "My_SG"
	description= "Allow inbound traffic"
	vpc_id= "vpc-ec8de496"

	ingress {
    		description = "TLS from VPC"
    		from_port   = 80
    		to_port     = 80
    		protocol    = "tcp"
    		cidr_blocks = ["0.0.0.0/0"]
  	}
	ingress {
    		description = "ssh"
    		from_port   = 22
    		to_port     = 22
    		protocol    = "tcp"
    		cidr_blocks = ["0.0.0.0/0"]
  	} 
	egress {
    		from_port   = 0
    		to_port     = 0
    		protocol    = "-1"
    		cidr_blocks = ["0.0.0.0/0"]
  	}
	tags = {
    		Name = "allow_tls"
  	}
}
resource "aws_ebs_volume" "my_vol" {
	availability_zone = "${aws_instance.my_inst.availability_zone}"
	size = 1
	tags = {
		Name = "MyVolume"
	}
}
resource "aws_instance" "my_inst" {
	ami = "ami-09d95fab7fff3776c"
	instance_type = "t2.micro"
	key_name = "abcd"
	security_groups = [ "My_SG" ]
	connection {
		type = "ssh"
		user = "ec2-user"
		private_key = file("C:/Users/This PC/Downloads/abcd.pem")
		host = aws_instance.my_inst.public_ip
	}
	provisioner "remote-exec" {
		inline = [
			"sudo yum install httpd php git -y",
			"sudo systemctl restart httpd",
			"sudo systemctl enable httpd",
			]
	}
	tags = {
		Name = "prashansa"
	}
}
resource "aws_volume_attachment" "Vol_Attach" {
	device_name = "/dev/sdh"
	volume_id = "${aws_ebs_volume.my_vol.id}"
	instance_id = "${aws_instance.my_inst.id}"
	depends_on = [
		aws_ebs_volume.my_vol,
		aws_instance.my_inst
		]
}
resource "null_resource" "NR" {
	depends_on = [
		aws_volume_attachment.Vol_Attach,
	]
	connection {
		type = "ssh"
		user = "ec2-user"
		private_key = file("C:/Users/This PC/Downloads/abcd.pem")
		host = aws_instance.my_inst.public_ip
	}
	provisioner "remote-exec" {
		inline = [
			"sudo mkfs.ext4 /dev/xvdh",
			"sudo mount /dev/xvdh /var/www/html",
			"sudo rm -rf /var/www/html/*",
			"sudo git clone https://github.com/Prashansa09/Hybrid_Cloud /var/www/html"
			]
	}
}
resource "aws_s3_bucket" "my_s3" {
	bucket = "nature0911"
	acl = "public-read"
	tags = {
		Name = "nature0911"
		Environment = "Dev"
		}
	versioning {
		enabled = true
		}

}
locals {
	s3_origin_id = "S3-nature0911"
}
resource "aws_s3_bucket_object" "object" {
	bucket = "nature0911"
	key = "download"
	source = "C:/Users/This PC/Downloads/download.jpg"
	content_type = "image or jpg"
	acl = "public-read"
	depends_on = [
		aws_s3_bucket.my_s3
		]
}
resource "aws_cloudfront_distribution" "my_cloudfront" {
	origin {
		domain_name = aws_s3_bucket.my_s3.bucket_domain_name
    		origin_id   = local.s3_origin_id
		custom_origin_config {
			http_port = 80
			https_port = 80
			origin_protocol_policy = "match-viewer"
			origin_ssl_protocols = ["SSLv3", "TLSv1", "TLSv1.1", "TLSv1.2"]
			}
		}
	enabled = true
	default_cache_behavior {
		allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    		cached_methods   = ["GET", "HEAD"]
    		target_origin_id = local.s3_origin_id
		forwarded_values {
      			query_string = false

     		cookies {
        		forward = "none"
      			}
    		}

    		viewer_protocol_policy = "allow-all"
    		min_ttl                = 0
    		default_ttl            = 3600
    		max_ttl                = 86400
  		}
	restrictions {
    		geo_restriction {
      			restriction_type = "none"
    			}
  		}
	viewer_certificate {
    		cloudfront_default_certificate = true
  		}
}