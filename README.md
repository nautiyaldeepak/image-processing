Image Processing
================
## AWS Services used
- [S3](https://aws.amazon.com/s3/)
- [Datasync](https://aws.amazon.com/datasync/)
- [Lambda](https://aws.amazon.com/lambda/)
- [EventBridge](https://aws.amazon.com/eventbridge/)
- [EFS](https://aws.amazon.com/efs/)
- [Batch](https://aws.amazon.com/batch/)

## Explanation [ why above services are used ]
> [!NOTE]
> Using these aws managed tools will lead to cost implications, there are some cost calculations done later in the doc. 
- `S3` - to store raw and transformed images.
- `Datasync` - Datasync provides high performance low latency to transfer data. Since, we're dealing with large image sizes using awscli to copy image would be slow & unreliable. With datasync large file transfers can be completed with high reliability & extraordinary speeds.
- `Lambda` - lambda is used to create datasync tasks and batch task which is then added to the queue.
- `EventBridge` - When an object is added to origin s3 bucket, eventbridge rule triggers the lambda.
- `EFS` - EFS provides us with high IOPS, also it has the flexibility to expand as the storage grows. Since we're dealing with large images, efs for storage makes more sense compared to standard storage.
- `Batch` - batch is used to execute transformation tasks. Batch queue is used to assign tasks. Then compute environment and job definition are used for execution.

## Architecture
> [!NOTE]
> Since it is not mentioned where the raw images are, Im assuming that they are on a local system/server. Even if the location of images is different there will be no serious change to the architecture.

![arch_image_process](https://github.com/nautiyaldeepak/image-processing/assets/30626234/11a5e9ec-9456-4647-a1ef-25c0c6f8a8f5)
1. User upload the image to origin s3 bucket which the user wants to transform. Since files are large use multipart upload.
2. Once is object is uploaded the s3 bucket, the eventbridge automatically triggers a lambda function and it also passes the bucket name and object name to the lambda.
3. Lambda function creates 3 resources, 2 datasync tasks and 1 job for the batch queue.
    - The 1st datasync task is to transfer data from `origin s3 bucket` to efs.
    - The 2nd datasync task is to transfer data from efs to `transform s3 bucket`. This task is required to save the image in transform bucket once the transformation is complete.
    - The job is created to be added in the queue, so that it can be processed by aws batch. The job is feeded all the relevant information to complete the job.
4. Once there is a job present in aws batch, the batch creates a new environment using job definition and compute environment to process the job which is present in the queue.
5. EFS is also created, when the compute environment is created, efs is also mounted to the resource.
6. Once the compute environment is up, it launches the script which executes the following instructions
    - Execute datasync task to copy contents from origin s3 to efs.
    - Run the python docker image which has the algorithm and process the image.
    - Once the image is processed, the second datasync task is executed which transfers the output image to the transform s3 bucket.
    - Once final datasync is compelete, delete both images from efs.
    - Terminate the environment
7. The transformed image is now present in transform s3 bucket.
> [!NOTE]
> Architecure diagram also includes Continious Integration process which is for building image and then deploying the image on ECR.

## Deploy aws infrastructure
- In terraform/variables.tf file add values for all variables.
- Please make sure to add `subnet-ids`, `vpc-id`, `vpc-cidr`
- The aws user that you're using should have the necessary permissions.
```
cd terraform
terraform init
terraform plan
terraform apply
```

## Delete aws infrastructure
> [!NOTE]
> make sure you S3 buckets are empty, otherwise buckets won't delete
```
terraform destroy
```

## Gitlab CI file
- `.gitlab-ci.yaml` file is for building the image & then deploying the image on ECR.

## Sample Cost Calculations
> [!NOTE]
> These are rough calculation to give a cost estimate.
- Assumptions
`imageSize=32GB` `processingTime=4hr` `instanceType=m5.4xlarge` `region=eu-north-1` `instancePriceSpot=$0.3488`
- Cost for s3 | Price per GB (S3 Standard) = $0.023 | Cost = 64GB*0.023USD/GB = 1.472USD ~ $1.5
- Cost of Compute | Using spot instances for processing | Cost = 4*0.3488USD =  1.3952USD ~ $1.4
- Cost of Datasync | $0.0125 per GB for data copied | Cost = 64*0.0125USD = 0.80USD ~ $0.8
- Cost of EFS | For 64 GB stored for 1 day | 64GB×0.30USD/GB/month× 1/30 =0.64USD ~ $0.6

- Total Cost = 1.5 + 1.4 + 0.8 + 0.6 + 0.1 (misc cost) = $4.4/image
Approx cost is $4.4 per image

## Important Question
- How important is this processing ? 
    - The reason for asking this question is to figure out if we can can use spotInstance, if the processing is important and the result is required asap, in that case we would have used EC2 on-demand instances. In this case I've enabled spot instance. Using spot instances will lead to cost savings.
- How big are the images ?
    - This would help us estimate how much storage is required. Anyways in our case we're using EFS, which can expand on demand. But using efs will lead to higher cost.
- What is the estimated processing time ?
    - This can help us set timeouts and configure relevant alerts for our jobs. In this case I've made an assumption that it can take upto 4 hours.
- What is more important cost or performance/reliability ?
    - There is always a trade off between cost and performance. In this setup I've give more importance that performace, although cost implications are also kept in mind when designing the architecture.

## Extra
- All necessary roles, policies & security groups are created via terraform templates.
- To reduce overall costs, we're using spot instances. If these image processing is critical, in that case we would use on-demand ec2 instance, which will lead to higher cost. 
- There are 2 scripts created.
    a. s3_trigger lambda python script
    b. bash script for compute environment
For both scripts, I've written psuedo code to give general idea what the scripts are suppose to do.
- You can tinker with the architecture by uploading the file architecture/architecture.excalidraw to [excalidraw](https://excalidraw.com/)
- The scripts that are written in `scripts/` directory, they are psuedo code, they are not functional but will give you a general idea what they're suppose to do. If you need a functional scripts, please let me know I'll write proper scripts.
- The `.gitlab-ci.yml` file is also not tested but will give you a general idea what it is suppose to do.
- I tried to design and explain the architecture to the best of my abilities, if something is not clear we can surely have a discussion.
- Terraform templates are functional, you can use the commands mentioned above to deploy/destroy the terraform resources.
- I've kept the repo public. This was not mentioned in the assignment description.