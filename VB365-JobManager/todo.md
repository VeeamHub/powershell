# TODOS:
 
 - Schedule delay only for next job with same repository (2 proxies can start jobs at the same time - throttling?)
    - Repos might be on the same proxy - how to handle then? Remember the last proxy used?
  
 - Group jobs based on a pattern (e.g. all SPO pages matching a pattern grouped to their own jobs) - Include this option in the naming pattern?
   - Like a pattern file with JSON
        ```
        "group1": [
            "pattern1",
            "pattern2",
            "pattern3"
        ]

  - Update functionality
    - Run through current jobs, re-calculate the object count e.g. for removed sites or newly added subsites
  - Rebalance
    - After updating being able to rebalance jobs so that in the end all jobs have the configured max object limit, but are still going to the same repository as before