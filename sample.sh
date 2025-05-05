EPOCHS="1 2"
LRS="1e-05 2e-05 4e-05 1e-04 2e-04 4e-04"
WRS="0.05 0.1 0.2"
VTS="2 4 8 16"

GPUQOPTS="-q gLrchq -l select=1:ncpus=4:mem=64G:ngpus=1 -v DOCKER_IMAGE=imc.tut.ac.jp/transformers-pytorch-cuda118:4.37.2"
TORCH_HOME=/work/${LOGNAME}/.cache/torch
TRANSFORMERS_CACHE=/work/${LOGNAME}/.cache/transformers
HF_HOME=/work/${LOGNAME}/.cache/huggingface
TRITON_CACHE_DIR=/work/${LOGNAME}/.cache/triton

generate_command(){
	epoch=${1}
	learningrate=${2}
	warmupratio=${3}
	virtual_tokens=${4}
	workdir=`pwd`
	cat <<EOF
	
cd ${workdir} && \
export TORCH_HOME=${TORCH_HOME} && \
export TRANSFORMERS_CACHE=${TRANSFORMERS_CACHE} && \
export HF_HOME=${HF_HOME} && \
export TRITON_CACHE_DIR=${TRITON_CACHE_DIR} && \
export TORCH_USE_CUDA_DSA=1 && \
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True && \
poetry run python source_selection/source_selection.py \
	--output_dir ./500-random-sourceselection/llama_ep${epoch}_lr${learningrate}_wr${warmupratio}_vt${virtual_tokens} \
	--num_epochs ${epoch} \
	--learning_rate ${learningrate} \
	--warmup_ratio ${warmupratio} \
	--num_virtual_tokens ${virtual_tokens}
EOF
}

for epoch in ${EPOCHS}; do
	for lr in ${LRS}; do
		for wr in ${WRS}; do
			for vt in ${VTS}; do
				generate_command ${epoch} ${lr} ${wr} ${vt} |\
				qsub ${GPUQOPTS} -N parameter_search_ep${epoch}_lr${lr}_wr${wr}_vt${vt} -k doe -j oe
				sleep 3
			done
		done
	done
done