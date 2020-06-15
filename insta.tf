provider "aws" {
  region = "ap-south-1"
  profile = "samyakaws"
}

resource "aws_security_group" "srule" {
	name = "allow_httpd"

	ingress {

		from_port  = 80
		to_port    = 80
		protocol   = "tcp"
		cidr_blocks = ["0.0.0.0/0"]

		
	}
	
	ingress {
		
		from_port  = 22
		to_port    = 22
		protocol   = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
	
	egress {
		from_port  = 0
		to_port    = 0
		protocol   = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}
	
	tags = {
	Name = "allow_httpd"
	}
}

resource "aws_instance" "web" {

              depends_on = [
		aws_security_group.srule,
                                     ]
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "mykey"
  security_groups = [ "allow_httpd" ]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/ASUS/Downloads/mykey.pem")
    host     = aws_instance.web.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "samyakos"
  }

}


resource "aws_ebs_volume" "esb1" {
  availability_zone = aws_instance.web.availability_zone
  size              = 1
  tags = {
    Name = "samebs"
  }
}
resource "aws_ebs_snapshot" "ex_snapshot" {
  volume_id = "${aws_ebs_volume.esb1.id}"

  tags = {
    Name = "samebs_snap"
  }
}


resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.esb1.id}"
  instance_id = "${aws_instance.web.id}"
  force_detach = true
}


output "myos_ip" {
  value = aws_instance.web.public_ip
}


resource "null_resource" "nulllocal2"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.web.public_ip} > publicip.txt"
  	}
}



resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.ebs_att,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/ASUS/Downloads/mykey.pem")
    host     = aws_instance.web.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/samyakjain9899/websitegit.git /var/www/html/"
    ]
  }
}

resource "null_resource" "gitdown"  {
	provisioner "local-exec" {
	    command = "git clone https://github.com/samyakjain9899/cloudimg.git"

  	}
}

resource "aws_s3_bucket" "mybucket" {
                depends_on=[
                                  null_resource.nullremote3
                                     ]
                bucket = "125buckam45"
                acl = "public-read"
}

resource  "aws_s3_bucket_object" "myobj1"{
               bucket = "125buckam45"
               key = "joker.jpg"
               source =  "C:/Users/ASUS/Desktop/cloudimg/joker.jpg "
               acl =  "public-read"
               content_type= "image/jpg"
               depends_on= [
                                aws_s3_bucket.mybucket
               ]
}
variable "var1" {
	default = "s3-"
}

locals {
s3_origin_id = "${var.var1}${aws_s3_bucket.mybucket.id}"
}


resource "aws_cloudfront_distribution" "s3_distribution" {
	origin {
	domain_name = "${aws_s3_bucket.mybucket.bucket_regional_domain_name}"
	origin_id   = "${local.s3_origin_id}"
	}

  	enabled             = true
  	is_ipv6_enabled     = true
  	comment             = "Some comment"
  
	default_cache_behavior {
    		allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    		cached_methods   = ["GET", "HEAD"]
    		target_origin_id = "${local.s3_origin_id}"

    		forwarded_values {
      			query_string = false

	      		cookies {
        			forward = "none"
      			}
    		}

    	viewer_protocol_policy = "allow-all"
    
 	}
	
	restrictions {
    		geo_restriction {
      			restriction_type = "none"
    		}
  	}

	viewer_certificate {
    		cloudfront_default_certificate = true
  	}

	depends_on=[
		aws_s3_bucket_object.myobj1
	]

	connection {
		type = "ssh"
		user = "ec2-user"
		private_key = file("C:/Users/ASUS/Downloads/mykey.pem")
		host = aws_instance.web.public_ip
	}
	provisioner "remote-exec" {
		inline = [
				"sudo su << EOF",
            					"echo \"<img src='http://${self.domain_name}/${aws_s3_bucket_object.myobj1.key}'>\" >> /var/www/html/web1.html",
           					"EOF"
			]
	}
	


}
resource "null_resource" "nulllocal1" {

	depends_on = [
		aws_cloudfront_distribution.s3_distribution
	]

	provisioner "local-exec" {
		command = "start chrome  ${aws_instance.web.public_ip}"
	}
}


