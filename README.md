# CryoSPARC v2.12.4 on-the-fly Cluster Guide

This repository is to install and start an on-the-fly CryoSPARC cluster on a SLURM HPC in the userspace inside a user job for CryoEM data analysis. No centralized installation is needed. Everything is maintenaned by the user in her own directory. 

This repo is better reviewed by a HPC system administrator of your institution first.


There are two steps to use the on-the-fly cluster on the HPC:

## Prerequisite 

- You need a CryoSparc license to install the cluster. Visit [CryoSPARC website](https://cryosparc.com/download/) to request yor own license. The license ID will be a UUID string in the email they send to you. The download address in the install script may change, please verify.  
- The HPC is using SLURM as job scheduler, and it is not sharing nodes between users.
- Change the cuda module/cuda path of initial_install.sh script
- Change the ssd disk path of initial_install.sh script if exists, or remove it from the scripts. Eg we are using /nvme_scratch. This scratch disk is purged with a prolog and epilog by the SLURM controller before and after jobs. 
- Verify the md5sum string of the master and slave tarball files in the scripts. The current is for CryoSparc 2.12.4 version. Please change accordingly. 
- Verify the compute node is accessible from your institution network. Get the IP address pattern of the compute nodes. 


## Install CryoSPARC using initial_install.sh (**Once in a life time only**). 
#### Clone or download all the files in the directory you are working 

To clone this repository, do:
```
git clone https://github.com/vigo332/cryosparc_onthefly.git
```

The installation directory needs to be accessible on all the HPC nodes. A network filesystem like NFS, GPFS or Lustre is preferred. 
If the currently directory is the $HOME directory, the installation will be changed to $HOME/software/cryosparc. Copy files there. 

#### Download the cryosparc2_master.tar.gz and cryosparc2_worker.tar.gz (Optional)
The script will automatically download them using the license provided if network is available. 

#### Install the cluster, run the command: 

```
sh initial_install.sh 2>&1 | tee -a install.log

```
The `install.log` is the log file used for further debug and assistance. This command will install the master and worker automatically with no intervene after initial parameters input (install_dir, license ID, email, password). It tries to unzip or download the cryosparc2_master.tar.gz and cryosparc2_worker.tar.gz and install them. Users are required to request their own license key from [CryoSPARC website](https://cryosparc.com/download/). 

A cryosparc user will be created when the master is installed. Email address and password is prompted at the beginning of installation. 

The script will add the installation path to your .bashrc file. 

**NB**: This script assumes using cuda10.0/toolkit/10.0.130 module if no cuda is specified. Please change accordingly.

##  Use submit_cryosparc_job.sbatch to start the cluster in the HPC job
`submit_cryosparc_job.sbatch` is a SLURM job script which automatically start the CryoSPARC cluster inside the job. The first node will run the CryoSPARC master and worker, the other nodes run as workers. The master/workers will be set automatically to the reserved compute nodes, and cleaned up when the job is terminated. 

To use: 
```
bash
sbatch submit_cryosparc_job.sbatch
```

The number of compute nodes to reserve can be changed with the -N option in the script. Reasonably set the timelimit `-t` option. 

To access the master web interface, visit eg http://10.10.10.X:39000, X is the node number (eg, if the master/first node is node2, X=2). Please check your compute node IP address to replace the 10.10.10.X like we use. 

**NB**: If the initial login failed with the message "User not found", ssh into the first node of the cluster (use `squeue` to show the nodes the cryosparc cluster is running) and run the command:

```
cryosparcm createuser --email <your_email> --password <your_password> --name <your_name>
```
Please use a dummy password. 


#### Setting the --ssdpath

For the CryoEM HPC cluster, the ssdpath `/nvme_scratch/$USER/cryosparc_scratch` directory is created automatically on each node during the run, the user does not need to do anything. 

Please note that after the job is finished or cancelled, this path will be automatically removed by the system.


#### Clean up your session lock

Occasionally, when your CryoSparc job ends ungracefully, there will be a file "/tmp/cryosparc-supervisor\*.sock" left on the master node. This will block other users' session from launching the cryosparc on the same master node, because it is the database socket lock file. 

To avoid such a conflict, please be sure to remove the file on the node, simply by:
```
for i in `seq 2 11`; do ssh node$i -C 'hostname; rm /tmp/cryosparc*.sock; rm /tmp/mongodb*sock'; done
```

