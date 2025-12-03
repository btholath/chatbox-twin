# Remove the wrong versions
sudo rm /usr/local/bin/terraform

# Download Linux AMD64 version
curl -O https://releases.hashicorp.com/terraform/1.14.1/terraform_1.14.1_linux_amd64.zip
unzip terraform_1.14.1_linux_amd64.zip
sudo mv terraform /usr/local/bin/
sudo chmod +x /usr/local/bin/terraform

# Verify
terraform --version