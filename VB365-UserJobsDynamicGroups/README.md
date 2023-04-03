## VeeamHub
Veeamhub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees. 

## 🤝🏾 License
Copyright (c) 2021 VeeamHub

- [MIT License](LICENSE)

## Project Notes
**Author:** David Bewernick (@d-works42)
**Version:** 1.0

**Function:** This script creates Azure AD dynamic groups to split up the users of a whole tenant based on the first two characters of their ObjectID. 
   The number of groups beeing created is depending on the array of first and second character.
   Per default, this script will create 64 groups, since the first charakter will be from "0" to "f" and the second character will be grouped in 4 expression ranges.
   VB365 backup jobs will be created for every dynamic group and separatly for Exchange Online and OneDrive.

**ATTENTION:** 
   !!! You need to use the Microsoft AzureADPreview module since the parameter "MembershipRule" is only available in the beta of GraphAPI.
   -> Install-Module AzureADPreview -Scope CurrentUser -AllowClobber !!!

**Requires:** AzureADPreview Module and a Microsoft subscription which includes at least Azure AD Premium P1 features.

