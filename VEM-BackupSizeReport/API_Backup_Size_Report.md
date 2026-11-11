**Querying the API for backup size report manually will require multiple queries in sequence.**  
*(This flow is similar to building a report from B&R via PowerShell)*
 
**Query Flow:**
1.	Query all of the jobs, filtering based on JobType of 'Backup' (customer would need to parse these results to filter to their specific jobs)
2.	Get the associated backup sessions for each backup job
3.	Get the restore points associated with each backup session
4.	Get the details of each backup file associated with each restore points
5.	Perform a summary of the size of the files, to provide a total in the report

**Output:**  
This script will return a simple summary of what Veeam reports as the size of data on disk for the backup jobs fed into the original query.  

Fields output by this script are:  Backup Job Name, File Name, Backup Size, Data Size, Deduplication Ratio, Compression Ratio, File Type, Creation Time (UTC)  

*Notes:*  
There would need to be additional details configured in any script/query to capture/display fewer/more details as necessary, but this script will return  a table as a result.  

This results will be the statistics which Veeam captured during the session, meaning that it will not account for post-job savings of ReFS or deduplicating storage appliances.  

This workflow was built by stepping through the API via the EnterPrise Manager web client to build out each "level" of the flow and gathering the specific details of each to perform.  
