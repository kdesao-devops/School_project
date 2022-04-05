FROM centos:centos8.1.1911

USER root

RUN yum -y update \
    && yum -y upgrade \
    && yum install -y python36-3.6* \
                       python3-pip-9* \
                       unzip-6* \
                       wget-1.19* \
                       git-2.18* \
                       curl-7.61* \
                       jq-1.5 \
                       tree-1.7*

RUN wget "https://releases.hashicorp.com/terraform/0.11.14/terraform_0.11.14_linux_amd64.zip" \
    && unzip "terraform_0.11.14_linux_amd64.zip" \
    && mv terraform /bin \
    && rm "terraform_0.11.14_linux_amd64.zip" \
    && curl -L https://raw.githubusercontent.com/warrensbox/terraform-switcher/release/install.sh | bash

RUN pip3 install --no-cache-dir \
    pip==9.0.1 \
    setuptools==38.4.0 \
    boto3==1.8 \
    awscli==1.14.30
