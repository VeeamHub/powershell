$access_key=''
$secret_key=''
$s3folder='sp-01'
$bucket_name='veeam-ps-ct02'
$repo_aws='AWS-S3-01'
$size_limit='102400'
$vbr_server='TPM03-VBR04-SP1.aperaturelabs.biz'
$sobr_name='SOBR-01'
$repo_ex1='REPO-01'
$repo_ex2='REPO-02'
$repo_path1='R:\Backup'
$repo_path2='S:\Backup'

Add-VBRAmazonAccount -AccessKey $access_key -SecretKey $secret_key

$aws_account = Get-VBRAmazonAccount
$bucket = Get-VBRAmazonS3Bucket -Connection $aws_connection -Name $bucket_name
$aws_connection = Connect-VBRAmazonS3Service -Account $aws_account -RegionType Global -ServiceType CapacityTier

New-VBRAmazonS3Folder -Connection $aws_connection -Bucket $bucket -Name $s3folder

$folder = Get-VBRAmazonS3Folder -Connection $aws_connection -Bucket $bucket

Add-VBRAmazonS3Repository -Name $repo_aws -AmazonS3Folder $folder -Connection $aws_connection -EnableSizeLimit -SizeLimit $size_limit

$server = Get-VBRServer -Name $vbr_server

Add-VBRBackupRepository -Name $repo_ex1 -Type WinLocal -Server $server  -Folder $repo_path1 -LimitConcurrentJobs -MaxConcurrentJobs 10 -UsePerVMFile
Add-VBRBackupRepository -Name $repo_ex2 -Type WinLocal -Server $server  -Folder $repo_path2 -LimitConcurrentJobs -MaxConcurrentJobs 10 -UsePerVMFile
Add-VBRScaleOutBackupRepository -Name $sobr_name -PolicyType DataLocality -Extent $repo_ex1, $repo_ex2 -UsePerVMBackupFiles -EnableCapacityTier -ObjectStorageRepository $repo_aws -OperationalRestorePeriod 7
