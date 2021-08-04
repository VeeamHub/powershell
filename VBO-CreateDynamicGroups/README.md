## VeeamHub
Veeamhub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees.

## Project Notes
Author: David Bewernick (Veeam Software)
Function: Creating AzureAD dynamic groups with user membership based on regex 

ATTENTION: 
	You need to use the AzureADPreview module since the parameter "MembershipRule" is only available in the beta of GraphAPI.
   -> Install-Module AzureADPreview -Scope CurrentUser -AllowClobber

Requires: AzureADPreview Module and a Microsoft subscription which includes at least Azure AD Premium P1 features.

## 🤝🏾 License
Copyright (c) 2021 VeeamHub

- [MIT License](LICENSE)
