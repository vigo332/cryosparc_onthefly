#!/bin/bash

#SBATCH -N 4               		## How many compute nodes this job will run on. 
#SBATCH -p defq             		## Which partition we would like to run on. 
#SBATCH -J cryosparc     		## This is the job name. 
#SBATCH -t 05:00:00       		## How long will it take: DD-HH:MM:SS
#SBATCH -o cryosparc2.%j.out       	## stdout file
#SBATCH -e cryosparc2.%j.err       	## stderr file


set -o pipefail
declare -a node_list

master_cmd=cryosparcm
worker_cmd=cryosparcw

master_port=39000

# specify a user specific scratch directory not to conflict with each other.
ssd_path="/nvme_scratch/$USER/cryosparc_scratch"

echoinfo () 
{
	echo -e "\e[32m[INFO] $@\e[0m"
}

echoerror ()
{
	echo -e "\e[31m[ERROR] $@\e[0m"
}

check_slurm ()
{
    # Check we are running under slurm and have a job ID, otherwise exit
    if [ -z $SLURM_JOB_ID ]; then
       echoerror "  No SLURM job ID is set - this script must be run as a SLURM batch job."
       exit 1
    fi
    echoinfo "  Running as job $SLURM_JOB_ID"
    echoinfo "  Running on node(s) $SLURM_JOB_NODELIST"
}


parse_slurm_nodes () 
{
	## Parse slurm node list
	node_list=($(scontrol show hostnames $SLURM_NODELIST))

	master_bindir=$(dirname $(which cryosparcm))
	worker_bindir=$(dirname $(which cryosparcw))


	## This is the first/Master node
	master_node=${node_list[0]}	

}


# update master node with job
update_master_config () 
{
	sed -i -E "s/CRYOSPARC_MASTER_HOSTNAME=\"[a-z0-9.]+\"/CRYOSPARC_MASTER_HOSTNAME=\"$master_node\"/" $master_bindir/../config.sh

	grep MASTER_HOSTNAME $master_bindir/../config.sh
}


start_master () 
{
	
	# remove the old unix sock lock

	if ls /tmp/cryosparc-*sock 1> /dev/null 2>&1; then
		lockfiles=`ls /tmp/cryosparc-*sock`

		if [[ $lockfiles != *"cannot access"* ]];
		then

			for i in $lockfiles
			do
				owner=`stat -c %U $i`
				if [[ $owner == $USER ]]
				then
					echoinfo "  Removing file $i"
					rm $i
					rm /tmp/mongodb*sock
				else
					echoerror "  There is a $i lockfile left by $owner from a previous session. "
					echoerror "  CryoSparc cannot obtain the database socket because this file can not be delete by you. "
					echoerror "  Please ask $owner to delete $i on $master_node ."
					echoerror "  Unfortunately, I have to quit."
					exit 1
				fi
			done
		fi
	else
		echoinfo "  No lock founded. "
	fi

	echoinfo "  Starting the Cryosparc Master on $master_node. "
	$master_cmd restart
	sleep 15

	# check if master web is alive
	nc -z -v -w5 $master_node $master_port

	if [[ $? -ne 0 ]];
	then
		echoinfo "  Master web 39000 is not available, exit. "
		exit 1;
	fi

	echoinfo "  Cryosparc Master is started on $master_node:$master_port"

}

cleanup_old_workers () 
{
	current_num_workers=$(cryosparcm cli "get_worker_nodes().__len__()")
	
	echoinfo "  There were $current_num_workers workers connected previously, cleaning"

	worker_list=" "
	
	for (( i=0; i<$current_num_workers; i++))
	do
		old_node=$(cryosparcm cli "get_worker_nodes()[$i][\"name\"]")
		worker_list="$worker_list $old_node"
	done

	echoinfo "  The previous workers are: $worker_list. "

	for w in $worker_list
	do
		for node in ${node_list[@]}
		do
			
			if [[ $w != $node ]]; 
			then
				echoinfo "  Removing old node $w from cluster."

				cryosparcm cli "remove_scheduler_target_node(\"$w\")"
			fi
		done
	done

}


prepare_ssd_scratch ()
{
	srun mkdir -p $ssd_path
}

connect_workers ()
{
	echoinfo "  Attempt to connect worker(s) ${node_list[@]} ."

	for node in ${node_list[@]}
    	do
		if [[ $node != $master_node ]];
		then
			printf "  Connecting worker on %s \n" $node
	
			ssh $node -C "module load cuda10.0/toolkit/10.0.130; cryosparcw connect --worker $node --master $master_node --port $master_port --ssdpath $ssd_path"
			sleep 5
		fi
	done

	# confirm master is also a worker
	module load cuda10.0/toolkit/10.0.130; cryosparcw connect --worker $master_node --master $master_node --port $master_port --ssdpath $ssd_path

}

remove_workers ()
{
	echoinfo "  Attempt to remove worker(s) ${node_list[@]} ."

	for node in ${node_list[@]}
    	do
		if [[ $node != $master_node ]];
		then
			printf "  Removing worker  %s \n" $node
	
			$master_cmd cli "remove_scheduler_target_node(\"$node\")"
			sleep 5
		fi
	done
}


shutdown_master () 
{	
	echoinfo "  Shutting down Cryosparc Master. "
	$master_cmd stop
}


start_cluster () 
{
	
	check_slurm

	parse_slurm_nodes

	update_master_config

	start_master

	cleanup_old_workers

	prepare_ssd_scratch

	connect_workers

}


cleanup () 
{
	echoerror "  Job is ending, cleaning up. "

	remove_workers

	shutdown_master

	echoerror "  Removing sock lock file. "

	srun rm /tmp/cryosparc*sock
	rm /tmp/cryosparc*sock
	rm /tmp/mongodb*sock

}


echoinfo "  Starting CryoSparc2 cluster"
echoinfo "  ---------------------------"


# cleanup when job is kill by scancel or timeout
trap 'cleanup' SIGINT SIGQUIT SIGTERM SIGKILL

start_cluster

sleep 99999999

cleanup









