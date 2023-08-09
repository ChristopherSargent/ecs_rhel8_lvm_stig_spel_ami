![alt text](ecs.logo.JPG)
* This repository contains instructions on using compliance as code's ansible playbooks to perform a base STIG hardening in an effort to create a hardened AMI/Gold Image. For any additional details or inquiries, please contact us at c.sargent-ctr@ecstech.com.
# [ComplianceAsCode](https://github.com/ComplianceAsCode/content)
* Deployed Red Hat 8 on t2.large with public IP and using alpha_key_pair

# Install ssm and compliance as code
1. ssh -i alpha_key_pair.pem ec2-user@NewRhel8PublicIP
2. sudo -i 
3. dnf install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm && sudo systemctl enable amazon-ssm-agent && sudo systemctl start amazon-ssm-agent
4. dnf install scap-security-guide ansible -y
5. ls /usr/share/xml/scap/ssg/content/

![Screenshot](resources/screen1.JPG)

6. oscap info /usr/share/xml/scap/ssg/content/ssg-rhel8-ds-1.2.xml

![Screenshot](resources/screen2.JPG)

# Run oscap scan to get baseline score
7. mkdir -p /home/ec2-user/oscap && cd /home/ec2-user/oscap
```
oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_stig --results-arf /tmp/arf.xml --report /home/ec2-user/oscap/rhel8-ami-oscap-pre.report.html --fetch-remote-resources --oval-results /usr/share/xml/scap/ssg/content/ssg-rhel8-ds-1.2.xml
```
8. chown -R ec2-user:ec2-user /home/ec2-user
9. scp -i "alpha_key_pair.pem" ec2-user@52.61.67.255:oscap/* .
* Open a second WSL terminal and cd to staging directory to pull file
10. Open report in browser

![Screenshot](resources/oscap1.JPG)

# Remidiate via ansible
11. cp /etc/ssh/sshd_config /etc/ssh/sshd_config.08092023 
12. visudo 
* Uncomment # %wheel  ALL=(ALL)       NOPASSWD: ALL or you wont be able to sudo after hardening
```
## Same thing without a password
%wheel  ALL=(ALL)       NOPASSWD: ALL
```
13. usermod -aG wheel ec2-user
14. ansible-playbook -i "localhost," -c local /usr/share/scap-security-guide/ansible/rhel8-playbook-stig.yml
* Note it takes about 25 minutes to run

![Screenshot](resources/ansible1.JPG)

15. cp /usr/share/scap-security-guide/ansible/rhel8-playbook-stig.yml /home/ec2-user/rhel8-playbook-stig-fixed.yml 
* I had to fix the playbook and staged it in the playbooks directory

# Run oscap scan to post hardening score
16. cd /home/ec2-user/oscap
```
oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_stig --results-arf /tmp/arf.xml --report /home/ec2-user/oscap/rhel8-ami-oscap-post.report.html --fetch-remote-resources --oval-results /usr/share/xml/scap/ssg/content/ssg-rhel8-ds-1.2.xml
```
17. chown -R ec2-user:ec2-user /home/ec2-user
18. scp -i "alpha_key_pair.pem" ec2-user@52.61.67.255:oscap/* .
* Open a second WSL terminal and cd to staging directory to pull file
19. Open report in browser

![Screenshot](resources/oscap2.JPG)

* Note the rhel8-ami-oscap-pre.report.html and rhel8-ami-oscap-post.report.html are in the reports directory
