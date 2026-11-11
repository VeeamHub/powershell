**Query Flow:**
1.	Query all of the jobs, filtering based on JobType of 'Backup' (customer would need to parse these results to filter to their specific jobs)
2.	Get the associated backup sessions for each backup job
3.  Get the task sessions associated with these backup sessions
4.	Get the VM restore points associated with each backup session
5.	Get the details of backup file associated with each restore points
6.	Provide output to CSV file of the results

**Output:**  
This script will return a simple summary of specific details from Veeam backup sessions, associated task sessions and VM restore points

Fields output by this script are:  VM Name, restore point creation time(UTC), restore point end time(UTC), restore point state, restore point result, failure reason, backup file size, backup job algorithm, restore point type, backup job name, name of vSphere tags included in backup job

*Notes:*  
There would need to be additional details configured in any script/query to capture/display fewer/more details as necessary, but this script will export a CSV file as a result.  

This results will be the statistics which Veeam captured during the session, meaning that it will not account for post-job savings of ReFS or deduplicating storage appliances.  

This workflow was built by stepping through the API via the EnterPrise Manager web client to build out each "level" of the flow and gathering the specific details of each to perform.  
