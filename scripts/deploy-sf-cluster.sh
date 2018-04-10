#!/usr/bin/env bash

# define variables to configure the service fabric cluster
cluster_name="sfTestCluster"
user_name="serviceFabricAdmin"
password="my_PassW0rD.123"
location="centralus"
certificate_folder="certs"
 
# for production, use at least five nodes to ensure reliability
# for development, three node clusters are also supported
cluster_size=5
 
# define the type and count of virtual machines used in the cluster
# the list of all SKUs is at https://aka.ms/linux-vm-skus
vm_sku="Standard_F4"

# find the certificate file that is required to connect to the cluster
# note that the $certificate_folder also contains a PFX version of the
# certificate that can be used to install the certificate on Windows by
# double clicking the file
certificate_file="$(find $certificate_folder -name '*.pem' -print -quit)"

if [ -z ${certificate_file} ]; then
    echo "Can't find the certificates. Make sure you have the certificates generated."
fi

create_rg() {
	echo "create a resource group that will hold everything related to the cluster"
	az group create --name "$cluster_name" --location "$location"
	if [ $? -ne 0 ]; then
		echo "Resource group $cluster_name already exists. Try a different name."
		exit 1
	fi 	
}

# create a new service fabric cluster
# access to the cluster will be secured via a self-signed certificate that
# also gets created by this command

create_sf_cluster() {
	echo "creating a new service fabric cluster"

	az sf cluster create								\
	  --resource-group "$cluster_name" 						\
	  --location "$location" 							\
	  --certificate-output-folder "$certificate_folder" 	  			\
	  --certificate-password "$password" 						\
	  --certificate-subject-name "$cluster_name.$location.cloudapp.azure.com" 	\
	  --cluster-name "$cluster_name" 						\
	  --cluster-size "$cluster_size" 						\
	  --os "UbuntuServer1604" 							\
	  --vault-name "$cluster_name" 							\
	  --vault-resource-group "$cluster_name"  					\
	  --vm-password "$password" 							\
	  --vm-user-name "$user_name" 							\
	  --vm-sku "$vm_sku"

	if [ $? -ne 0 ]; then
	  echo "error creating the cluster. Cleaning up the resource group."
	  az group delete --name $cluster_name --no-wait
	  exit 1
	fi
}

show_sf_cluster() {
	#check the status of the deployment"
	#note that deploying a new cluster for the first time make 30+ minutes"
	#when the cluster is fully set up, the 'clusterState' field of json"
	#output by the command below will no longer show as 'Deploying'"
	echo "check the status of the deployment"
	az sf cluster show	 \
	  --name "$cluster_name" \
	  --resource-name "$cluster_name"
}
# from now on, we will use the service fabric command line tool (sfctl) as
# opposed to the more general azure command line tool (az) which we used above
# for setting up the cluster
# the sfctl tool is based on python and the requests library, so we need to
# enable python to find the certificate required to connect to the cluster
# which we do by setting the following environment variable

select_sf_cluster() {
	export REQUESTS_CA_BUNDLE="$certificate_file"
	 
	echo "connect to the cluster"
	echo "note that the no-verify flag needs to be passed since the command"
	echo "used above to create the cluster generated a self-signed certificate"
	sfctl cluster select \
	  --endpoint "https://$cluster_name.$location.cloudapp.azure.com:19080" \
	  --pem "$certificate_file" \
	  --no-verify
}
 
check_cluster_health() {
	echo "verify that we were able to connect to the cluster"
	sfctl cluster health
}

create_sf_cluster
show_sf_cluster
select_sf_cluster
check_cluster_health
