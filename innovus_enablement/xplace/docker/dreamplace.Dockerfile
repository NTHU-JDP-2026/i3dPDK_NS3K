# DREAMPlace runtime for run_dreamplace_gp.sh (DREAMPLACE_IMAGE, default dreamplace-pa:cu110):
#   docker build -t dreamplace-pa:cu110 -f dreamplace.Dockerfile .
# limbo018/dreamplace:cuda (torch 1.7.1, CUDA 11.0) is what ~/DREAMPlace/install was built in;
# it lacks the optimizers DREAMPlace imports (--no-deps: keep its torch).
FROM limbo018/dreamplace:cuda
RUN pip install --no-deps torch_optimizer==0.3.0 pytorch_ranger==0.1.1 ncg_optimizer==0.2.2
ENV MPLCONFIGDIR=/tmp/mpl
