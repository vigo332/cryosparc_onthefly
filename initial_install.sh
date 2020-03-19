#!/bin/bash

echo -e "This script is only intended for installing CryoSparc 2.12.0 on a HPC cluster with SLURM job scheduler without node sharing. "
echo -e "Installing in other places may fail."
echo -e "Also you might want to change the ."


echo -e "All Rights Reserved."
echo -e "Author:	Wei Guo"
echo -e "Email:		vigo332@gmail.com"
echo -e "Date:		09/13/2019"


set -u
set -o pipefail

db_path_name="cryosparc2_database"

master_dir="cryosparc2_master"
worker_dir="cryosparc2_worker"

master_tar="cryosparc2_master.tar.gz"
worker_tar="cryosparc2_worker.tar.gz"
master_hash="3cc45d414fee04e887b8fc35af493f00"
worker_hash="e4e0182db459b98ee7a05aaf8b0615af"

install_version="2.12.0"

echoinfo () 
{
	echo -e "\e[32m[INFO] $@\e[0m"
}

echoerror ()
{
	echo -e "\e[31m[ERROR] $@\e[0m"



check_patch ()
{
	if [[ ! -f install.09102019.patch ]]
	then
		echoerror "  Patch file install.09102019.patch is not found. Please download it to $PWD. "
		exit 1;
	fi

	if [[ ! -f bin_cryosparcm.11262019.patch ]]
	then
		echoerror "  Patch file bin_cryosparcm.11262019.patch is not found. Please download it to $PWD. "
		exit 1;
	fi
}


# set install_dir
set_paths () 
{
	echoinfo "  ==================="
	echoinfo "  Setting up installation paths. "
	echoinfo "  Please specificy the installation directory. "
	echoinfo "  The installation path should not be your \$HOME. "
	echoinfo "  If you set to your \$HOME, it will be automatically set to \$HOME/software/cryosparc. "

	read -p "  Press Enter for the current working directory: " install_dir
	printf "\n"

	if [[ $install_dir == "" ]]
	then
		if [[ $PWD == $HOME ]]
		then
			install_dir=$PWD/software/cryosparc
		else
			install_dir=$PWD
		fi
	else
		if [[ ! -d $install_dir ]]
		then
			mkdir -p $install_dir
		fi
	fi
	
	db_path=$install_dir/$db_path_name

	if [[ ! -d $db_path ]]
	then
		mkdir $db_path
	fi

	echoinfo "  Setting installation path to $install_dir."
	echoinfo "  Setting database path to $db_path."

}


# Set license ID
set_license ()
{
	echoinfo "  Please obtain your license id from cryosparc.com "
	read -p "  CryoSparc license ID (UUID): " LICENSE_ID
	
	while [[ ! $LICENSE_ID =~ [a-f0-9]{8}-[a-f0-9]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12} ]];
	do
		echoerror "  The license id does not seem to be a valid uuid string. Please check. "
		read -p "  Please input a valid UUID license: " LICENSE_ID
		printf "\n"
	done
}


# set login email
set_email ()
{
	email=""
	while [[ ! "$email" =~ ^[a-zA-Z0-9.]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]];
	do
		read -p "  Your Login Email Address: (@example.com, lower case. ): " email
		printf "\n"
	done
}


# set password
set_password ()
{
	password1='1'
	password2='2'

	read -sp "  Set a password for CryoSparc web: " password1
	printf "\n"
	while [[ $password1 = "" ]]
	do
		echoerror "  Password is empty, please input again... "
	done

	counter=0
	while [[ $password1 != $password2 ]];
	do
		read -sp "  Confirm password for CryoSparc web: " password2
		printf "\n"

		if [[ $password1 != $password2 ]];
		then
			echoerror "  Passwords do not agree, try again..."
			let counter+=1

			if [[ $counter -lt 3 ]];
			then
				continue;
			else
				echoerror "  Failed 3 times, aborting..."
				exit 1;
			fi
		fi	
	done

	password=$password1
}


# set cuda path
set_cuda_path () 
{
	# check if exists
	nvcc=`command -v nvcc`
	if [[ $? -ne 0 ]];
	then
		echoinfo "  Cuda (nvcc) is not found in environment, loading cuda10.0/toolkit/10.0.130 as a module... "
		module load cuda10.0/toolkit/10.0.130
		
		if [[ $? -ne 0 ]];
		then
			echoerror "  Loading cuda10.0/toolkit/10.0.130 failed. Quitting. "
			exit 1;
		fi

		echoinfo "  Current loaded modules are "
		module list
	fi

	nvcc=`which nvcc`

	cuda_path=$(dirname $(dirname $nvcc))
}


display_input ()
{
	echoinfo "  #####################"
	echoinfo "  Finishing input setup"
	echoinfo "  Variables are: "
	echoinfo "  --install_dir: " $install_dir
	echoinfo "  --db_path: " $db_path
	echoinfo "  --license: " $LICENSE_ID
	echoinfo "  --email: " $email
	echoinfo "  --cuda_path: " $cuda_path
}


install_master () 
{
	cd $install_dir/$master_dir

	install_sh_hash='b373d447e662fec40e050cab297e4806'
	bin_cryosparcm_hash='d300f06a820d454c77d77f635aba7f76'

	md5_install=`md5sum install.sh | awk '{ print $1 }'`
	if [[ $md5_install != $install_sh_hash ]]
	then
		echoinfo "  Patching install.sh file for security."
		patch -N -s install.sh < ../install.09102019.patch
	fi
	
	md5_cryosparcm=`md5sum bin/cryosparcm | awk '{ print $1 }'`
	if [[ $md5_cryosparcm != $bin_cryosparcm_hash ]]
	then
		echoinfo "  Patching bin/cryosparcm for security."
		patch -N -s bin/cryosparcm < ../bin_cryosparcm.11262019.patch
	fi

	echoinfo "  Installing master with command:"
	echoinfo "  ./install.sh --license $LICENSE_ID --hostname $(hostname -s) --dbpath $db_path --insecure --yes"
	./install.sh --license $LICENSE_ID --hostname $(hostname -s) --dbpath $db_path --insecure --yes
	
	# get name from email
	name=`echo $email | awk -F@ '{ print $1}'`

	echoinfo "  Starting master daemon as test"
	$install_dir/$master_dir/bin/cryosparcm start &

	sleep 20 
	# check status for installation debug.
	$install_dir/$master_dir/bin/cryosparcm status

	# Creating user
	## !! Dangerous with password in command line !!
	echoinfo "Creating initial user $email"
	set +o history
	$install_dir/$master_dir/bin/cryosparcm createuser --email $email --password $password --name $name
	set -o history
	$install_dir/$master_dir/bin/cryosparcm stop

	cd ../
}


prepare_master_files ()
{

	cd $install_dir
	echoinfo "  Installing master in $install_dir/$master_dir."

	# Just download the package in case of pollution 

	wget -q --no-check-certificate https://get.cryosparc.com/download/worker-latest/$LICENSE_ID -O $master_tar

	md5value=`md5sum $master_tar | awk '{ print $1 }'`

	if [[ $md5value == $master_hash ]]
	then
		echoinfo "  md5 hash value is $md5value, file checksum matches. "
		echoinfo "  Unzipping $master_tar file, this might take a while..."
		tar zxf $master_tar
		echoinfo "  Proceed to worker install"
		install_master
	else
		echoerror "  Downloaded $master_tar does not match hash $master_hash, aborting..."
		exit 1;
	fi
}


install_worker () 
{
	cd $install_dir/$worker_dir
	echoinfo "  Installing worker with: ./install.sh --license $LICENSE_ID --cudapath $cuda_path"
	./install.sh --license $LICENSE_ID --cudapath $cuda_path
	
	cd ../
}


prepare_worker_files ()
{

	cd $install_dir

	echoinfo "  Installing worker in $install_dir/$worker_dir in cluster mode."

	wget -q --no-check-certificate https://get.cryosparc.com/download/worker-latest/$LICENSE_ID -O $worker_tar

	md5value=`md5sum $worker_tar | awk '{ print $1 }'`

	if [[ $md5value == $worker_hash ]]
	then
		echoinfo "  md5 hash value is $md5value, file checksum matches. "
		echoinfo "  Unzipping $worker_tar file, this might take a while..."
		tar zxf $worker_tar
		echoinfo "  Proceed to worker install"
		install_worker
	else
		echoerror "  Downloaded $worker_tar does not match hash $worker_hash, aborting..."
		exit 1;
	fi
}


generate_worker_cluster_files ()
{
	cd $install_dir

cat <<'EOF' > $worker_dir/cluster_script.sh
#!/usr/bin/env bash
#SBATCH --job-name cryosparc_{{ project_uid }}_{{ job_uid }}
#SBATCH -p defq
#SBATCH -o {{ job_dir_abs }}
#SBATCH -e {{ job_dir_abs }}

module load cuda10.0/toolkit/10.0.130

available_devs=""
for devidx in $(seq 0 15);
do
    if [[ -z $(nvidia-smi -i $devidx --query-compute-apps=pid --format=csv,noheader) ]] ; then
        if [[ -z "$available_devs" ]] ; then
            available_devs=$devidx
        else
            available_devs=$available_devs,$devidx
        fi
    fi
done
export CUDA_VISIBLE_DEVICES=$available_devs

{{ run_cmd }}

EOF


cat <<EOF > $worker_dir/cluster_info.json 
{
    "name" : "SLURM_CLUSTER",
    "worker_bin_path" : "$install_dir/$worker_dir/bin",
    "send_cmd_tpl" : "ssh loginnode {{ command }}",
    "qsub_cmd_tpl" : "sbatch {{ script_path_abs }}",
    "qstat_cmd_tpl" : "squeue -j {{ cluster_job_id }}",
    "qdel_cmd_tpl" : "scancel {{ cluster_job_id }}",
    "qinfo_cmd_tpl" : "sinfo",
    "transfer_cmd_tpl" : "scp {{ src_path }} loginnode:{{ dest_path }}"
}

EOF

}


add_cryosparc_path_to_bashrc () 
{
	echoinfo "  To get CryoSparc cluster work on CryoHPC across nodes, the paths need to be added to your $HOME/.bashrc."

	echo "#   CryoSparc path" >> $HOME/.bashrc
	echo "export PATH=$install_dir/$master_dir/bin:\$PATH" >> $HOME/.bashrc
	echo "export PATH=$install_dir/$worker_dir/bin:\$PATH" >> $HOME/.bashrc
	echo "# Add libcuda to LD_LIBRARY_PATH so that cryosparc workers can use GPU." >> $HOME/.bashrc
	echo "export LD_LIBRARY_PATH=/cm/local/apps/cuda/libs/current/lib64:\$LD_LIBRARY_PATH" >> $HOME/.bashrc

}

check_patch

set_paths

set_license

set_email

set_password

set_cuda_path

display_input

prepare_master_files

prepare_worker_files

generate_worker_cluster_files

add_cryosparc_path_to_bashrc

echo "##########################"
echo "# Installation Finished! #"
echo "##########################"



