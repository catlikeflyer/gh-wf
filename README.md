# Github Workflows
Repo to test and learn about Github Workflows and Actions
name: DHN workflow

on:
  push:
    branches:
      - "A01025276"

  pull_request:
    branches:
      - "*" # matches every branch that doesn't contain a '/'
      - "*/*" # matches every branch containing a single '/'
      - "**" # matches every branch

jobs:
  lint:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v2

      - name: Set up Python
        uses: actions/setup-python@v2
        with:
          python-version: "3.10"

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install flake8 pytest
          if [ -f DHN/requirements.txt ]; then pip install -r DHN/requirements.txt; fi

      - name: Lint with flake8
        run: |
          flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics
          flake8 . --count --exit-zero --max-complexity=10 --max-line-length=127 --statistics

  pytest:
    runs-on: ubuntu-latest
    needs: lint

    steps:
      - name: Checkout repository
        uses: actions/checkout@v2

      - name: Set up Python
        uses: actions/setup-python@v2
        with:
          python-version: "3.10"

      - name: Install dependencies
        run: |
          python -m pip install pytest pytest-cov
          python -m pip install --upgrade pip
          pip install -r DHN/requirements.txt

      - name: Run pytest
        run: |
          pytest --cov=DHN --cov-report=xml

      - name: Upload coverage report
        uses: actions/upload-artifact@v2
        with:
          name: coverage-report
          path: ./coverage.xml

  package:
    name: Package
    runs-on: ubuntu-latest
    needs: pytest
    if: ${{ github.event_name != 'pull_request' }}

    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: Install Dependencies
        run: |
          pip install -r DHN/requirements.txt

      - name: Package
        run: zip app.zip DHN/app.py

  dockerize:
    runs-on: ubuntu-latest
    needs: package
    if: ${{ github.event_name != 'pull_request' }}

    steps:
      - name: Checkout repository
        uses: actions/checkout@v2

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Configure Docker Buildx
        uses: docker/setup-buildx-action@v1

      - name: Log in to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1
        with:
          registry-type: public

      - name: Build and tag image
        uses: docker/build-push-action@v4
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: d0z3f1c0/501ecr
          IMAGE_TAG_1: A01025276
          IMAGE_TAG_2: latest
        with:
          context: ./DHN
          tags: |
            ${{ env.ECR_REGISTRY }}/${{ env.ECR_REPOSITORY }}:${{ env.IMAGE_TAG_1 }}
            ${{ env.ECR_REGISTRY }}/${{ env.ECR_REPOSITORY }}:${{ env.IMAGE_TAG_2 }}_${{env.IMAGE_TAG_1}}
          outputs: type=docker,dest=/tmp/${{ env.IMAGE_TAG_1 }}_${{ env.IMAGE_TAG_2 }}.tar

      - name: Save image
        uses: actions/upload-artifact@v3
        env:
          IMAGE_TAG_1: A01025276
          IMAGE_TAG_2: latest
        with:
          name: ${{ env.IMAGE_TAG_1 }}_${{ env.IMAGE_TAG_2 }}
          path: /tmp/${{ env.IMAGE_TAG_1 }}_${{ env.IMAGE_TAG_2 }}.tar

      - name: Save Docker image artifact
        uses: actions/upload-artifact@v2
        with:
          name: docker-image
          path: .

  deploy:
    runs-on: ubuntu-latest
    needs: dockerize
    if: ${{ github.event_name != 'pull_request' }}

    steps:
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Read artifact
        uses: actions/download-artifact@v3
        env:
          IMAGE_TAG_1: A01025276
          IMAGE_TAG_2: latest
        with:
          name: ${{ env.IMAGE_TAG_1 }}_${{ env.IMAGE_TAG_2 }}
          path: /tmp

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1
        with:
          registry-type: public

      - name: Deploy image 1
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: d0z3f1c0/501ecr
          IMAGE_TAG1: A01025276
          IMAGE_TAG2: latest
        run: |
          docker load --input /tmp/${{env.IMAGE_TAG1}}_${{env.IMAGE_TAG2}}.tar
          docker image ls -a
          docker push ${{env.ECR_REGISTRY}}/${{env.ECR_REPOSITORY}}:${{env.IMAGE_TAG1}}

      - name: Deploy image 2
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: d0z3f1c0/501ecr
          IMAGE_TAG1: A01025276
          IMAGE_TAG2: latest
        run: |
          docker load --input /tmp/${{env.IMAGE_TAG1}}_${{env.IMAGE_TAG2}}.tar
          docker image ls -a
          docker push ${{env.ECR_REGISTRY}}/${{env.ECR_REPOSITORY}}:${{env.IMAGE_TAG2}}_${{env.IMAGE_TAG1}}