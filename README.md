# ms-windows
## Various Microsoft PS Scripts for Sysadmins
## Date: Mon April 20 13:40 EST 2020

Scripts are divided into categories for ease of searching.
- Admin_Management: issues I have had with multiple  host machines and needed a script to automate the tasks.
- Update_Management: scripts that forces applications to update when their auto updating agent wasn't fast enough/ required user interaction.
- Vuln_Management: Scripts to remediate common vulnerabilities or to harden systems with best secruity practices.
- Scanners: Scripts built into utilities to perform a wide spread of functions:
    - enum_script.psm1: can be used to scan active IP's on a network based on which networks your network adapters are connected to, scan         for active ports either by manual selection or common ports, PSRemoting (if the host has it enabled and you have credentials to           the remote host) to conduct enumeration of settings and other information of interest.
 

These scripts are built in mind that you do not want:
    1. Alert the user of any changes or your presence on their machine.
    2. Supress forced reboots (unless otherwise specified in the script).
    3. Leave minimal traces on the user's machine.
