This script runs on the Security Monitoring Tools EC2 in the security account via cron

*/4 * * * * /home/ubuntu/ec2-create-alertv2.sh stg
*/4 * * * * /home/ubuntu/ec2-create-alertv2.sh prod
