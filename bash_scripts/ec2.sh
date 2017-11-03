#!/usr/bin/env bash

echo ""
echo "Welcome to Joseph Fang's magic EC2 instance launch script"
echo ""
echo "I will launch an r3.xlarge instance in the default VPC for you, using a key and security group we will create."
echo ""

echo "The utility 'jq' is required for this script to detect the hostname of your ec2 instance ..."
echo "Detecting 'jq' ..."
if [ -z `which jq` ]; then
  echo "'jq' was not detected. Installing 'jq' ..."
  bash ./jq_install.sh
  PROJECT_HOME=`pwd`
  export PATH=$PATH:$PROJECT_HOME/bin
else
  echo "'jq' was detected ..."
fi

# Can't proceed if jq still not detected
if [ -z `which jq` ]; then
  echo "'jq' was still not detected. We use 'jq' to create the 'agile_data_science' key and to get the external hostname of the ec2 instance we create."
  echo "Please install jq, or open the script './ec2.sh' and use manually, creating the file './datawizard.pem' manually."
  echo "'jq' install instructions are available at https://github.com/stedolan/jq/wiki/Installation"
  echo ""
  echo "Goodbye!"
  echo ""
  exit
fi

echo "Creating security group 'datawizard' ..."
aws ec2 create-security-group --group-name datawizard --description "Security group for the one and only mad scientist"

echo ""
echo "Detecting external IP address ..."
EXTERNAL_IP=`dig +short myip.opendns.com @resolver1.opendns.com`

echo "Authorizing port 22 to your external IP ($EXTERNAL_IP) in security group 'datawizard' ..."
aws ec2 authorize-security-group-ingress --group-name datawizard --protocol tcp --cidr $EXTERNAL_IP/32 --port 22

echo ""
echo "Generating keypair called 'steinsgate' ..."             # Lose start "  # Lose end " # Make '\n' a newline
aws ec2 create-key-pair --key-name datawizard|jq .KeyMaterial|sed -e 's/^"//' -e 's/"$//'| awk '{gsub(/\\n/,"\n")}1' > ./datawizard.pem
echo "Changing permissions of 'datawizard.pem' to 0600 ..."
chmod 0600 ./datawizard.pem

echo ""
echo "Detecting the default region..."
DEFAULT_REGION=`aws configure get region`
echo "The default region is '$DEFAULT_REGION'"

# There are no associative arrays in bash 3 (Mac OS X) :(
echo "Determining the image ID to use according to region..."
case $DEFAULT_REGION in
  ap-south-1) UBUNTU_IMAGE_ID=ami-4d542222
  ;;
  us-east-1) UBUNTU_IMAGE_ID=ami-4ae1fb5d
  ;;
  ap-northeast-1) UBUNTU_IMAGE_ID=ami-65750502
  ;;
  eu-west-1) UBUNTU_IMAGE_ID=ami-cbfcd2b8
  ;;
  ap-southeast-1) UBUNTU_IMAGE_ID=ami-93a800f0
  ;;
  us-west-1) UBUNTU_IMAGE_ID=ami-818fdfe1
  ;;
  eu-central-1) UBUNTU_IMAGE_ID=ami-5175b73e
  ;;
  sa-east-1) UBUNTU_IMAGE_ID=ami-1937ac75
  ;;
  ap-southeast-2) UBUNTU_IMAGE_ID=ami-a87c79cb
  ;;
  ap-northeast-2) UBUNTU_IMAGE_ID=ami-9325f3fd
  ;;
  us-west-2) UBUNTU_IMAGE_ID=ami-a41eaec4
  ;;
  us-east-2) UBUNTU_IMAGE_ID=ami-d5e7bdb0
  ;;
esac
echo "The image for region '$DEFAULT_REGION' is '$UBUNTU_IMAGE_ID' ..."

# Launch our instance, which ec2_bootstrap.sh will initialize, store the ReservationId in a file
echo ""
echo "Initializing EBS optimized r3.xlarge EC2 instance in region '$DEFAULT_REGION' with security group 'steinsgate', key name 'steinsgate' and image id '$UBUNTU_IMAGE_ID' using the script 'aws/ec2_bootstrap.sh'"
aws ec2 run-instances \
    --image-id $UBUNTU_IMAGE_ID \
    --security-groups datawizard \
    --key-name datawizard \
    --user-data file://aws/ec2_bootstrap.sh \
    --instance-type r3.xlarge \
    --ebs-optimized \
    --block-device-mappings '{"DeviceName":"/dev/sda1","Ebs":{"DeleteOnTermination":true,"VolumeSize":1024}}' \
    --count 1 \
| jq .ReservationId | tr -d '"' > .reservation_id

RESERVATION_ID=`cat ./.reservation_id`
echo "Got reservation ID '$RESERVATION_ID' ..."

# Use the ReservationId to get the public hostname to ssh to
echo ""
echo "Sleeping 10 seconds before inquiring to get the public hostname of the instance we just created ..."
sleep 5
echo "..."
sleep 5
echo "Awake!"
echo ""
echo "Using the reservation ID to get the public hostname ..."
INSTANCE_PUBLIC_HOSTNAME=`aws ec2 describe-instances | jq -c ".Reservations[] | select(.ReservationId | contains(\"$RESERVATION_ID\"))| .Instances[0].PublicDnsName" | tr -d '"'`

echo "The public hostname of the instance we just created is '$INSTANCE_PUBLIC_HOSTNAME' ..."
echo "Writing hostname to '.ec2_hostname' ..."
echo $INSTANCE_PUBLIC_HOSTNAME > .ec2_hostname
echo ""

echo "Now we will tag this ec2 instance and name it 'Mad_Scientist' ..."
INSTANCE_ID=`aws ec2 describe-instances | jq -c ".Reservations[] | select(.ReservationId | contains(\"$RESERVATION_ID\"))| .Instances[0].InstanceId" | tr -d '"'`
aws ec2 create-tags --resources $INSTANCE_ID --tags Key=Name,Value=Mad_Scientist
echo ""

echo "After a few minutes (for it to initialize), you may ssh to this machine via the command in red: "
# Make the ssh instructions red
RED='\033[0;31m'
NC='\033[0m' # No Color
echo "Note: only your IP of '$EXTERNAL_IP' is authorized to connect to this machine."
echo ""
echo "NOTE: IT WILL TAKE SEVERAL MINUTES FOR THIS MACHINE TO INITIALIZE. PLEASE WAIT FIVE MINUTES BEFORE LOGGING IN."
echo ""
echo "Note: if you ssh to this machine after a few minutes and there is no software in \$HOME, please wait a few minutes for the install to finish."

echo ""
echo "Note: after a few minutes, now you will need to run ./ec2_create_tunnel.sh to forward ports 5000 and 8888 on the ec2 instance to your local ports 5000 and 8888. This way you can run the example web applications on the ec2 instance and browse them at http://localhost:5000 and you can view Jupyter notebooks at http://localhost:8888"
echo "If you tire of the ssh tunnel port forwarding, you may end these connections by executing ./ec2_kill_tunnel.sh"
echo ""
echo "---------------------------------------------------------------------------------------------------------------------"
echo ""
echo "Thanks for embarking on this data journey with Joseph Fang!"
echo ""
echo ""
echo ""
