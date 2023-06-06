FROM public.ecr.aws/lambda/python:3.8
COPY requirements.txt .
RUN  pip3 install -r requirements.txt --target "${LAMBDA_TASK_ROOT}"
COPY ./python3/app.py ${LAMBDA_TASK_ROOT}
CMD ["app.handler"]