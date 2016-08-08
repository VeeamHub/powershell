# UnattendedInstall

**Author:** Timothy Dewin

**Function:** Auto install B&R + Enterprise Manager + Update. Might be useful for test install or beta installs

**Requires:** Avalability Suite v9 ISO mounted on drive (f.e D:) + license under c:\silent + update under c:\silent

**Usage:** Adapt drive location, license location and update location. Then run ps1 script as administrator (log on as local administrator)

Sections can be removed. For example, you might not want to create a new local administrator automatically. 

Script only test with a computer that was NOT joined to the domain.

Script was kept very simple for show case reasons. It does not do any verification and expect all components to be installed succesfully.