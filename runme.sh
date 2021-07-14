#!/bin/bash

set -x

datetime=$(date +"%Y%m%d%H%M%S")

SERVER="node041 node042"
CLIENT="node041 node042"
GPU=2

PERF_HOME=/home/frank/perftest
results=/home/frank/results/perftest/$datetime
mkdir -p $results
#DISABLE GPUDIRECT MLX5_SCATTER_TO_CQE=0
CQE='MLX5_SCATTER_TO_CQE=0'

for srv in $SERVER
do
    for cli in $CLIENT
	do

	#Host-to-host(CPU-to-CPU)
		#Launch server in background
		ssh $srv $PERF_HOME/ib_write_bw -a -F -d mlx5_0 &
		sleep 2
		#Lauch client
		echo "h2h_${srv}-to-${cli}"
		ssh $cli $PERF_HOME/ib_write_bw -a -F -d mlx5_0 $srv |& tee $results/h2h_${srv}-to-${cli}.log
		sleep 2

	#Host-to-GPU
		#Server
		ssh $srv $CQE $PERF_HOME/ib_write_bw -a -F -d mlx5_0 --use_cuda=${GPU} &
		sleep 2
		#Client
		echo "h2d_${srv}-to-${cli}"
		ssh $cli $PERF_HOME/ib_write_bw -a -F -d mlx5_0 $srv |& tee $results/h2d_${srv}-to-${cli}.log
		sleep 2

	#GPU-to-Host
		#Server
		ssh $srv $PERF_HOME/ib_write_bw -a -F -d mlx5_0 &
		sleep 2
		#client
		echo "d2h_${srv}-to-${cli}"
		ssh $cli $CQE $PERF_HOME/ib_write_bw -a -F -d mlx5_0 --use_cuda=${GPU} $srv |& tee $results/d2h_${srv}-to-${cli}.log
		sleep 2

	#GPU-to-GPU
		#Server
		ssh $srv $CQE $PERF_HOME/ib_write_bw -a -F -d mlx5_0 --use_cuda=${GPU} &
		sleep 2
		echo "d2d_${srv}-to-${cli}"
		ssh $cli $CQE $PERF_HOME/ib_write_bw -a -F -d mlx5_0 --use_cuda=${GPU} $srv |& tee $results/d2d_${srv}-to-${cli}.log
		sleep 2
	done
done

#TO-DO results processing

grep 65536 $results/* |awk '{print $1,$5}'

