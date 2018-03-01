# SUMMA hydrologic modeling approach using an iRODS backend via DavRODS

This project demonstrates using files stored in [iRODS](https://irods.org) as the input to SUMMA jobs via a [DavRODS](https://github.com/UtrechtUniversity/davrods) mount, as well as the output destination for the results, all running in Docker.

<img width="80%" alt="Network diagram" src="https://user-images.githubusercontent.com/5332509/36870041-c055cdae-1d6b-11e8-9964-d6fc6b564153.png">

**NOTE**: makes use of the [docker-volume-davfs](https://github.com/fentas/docker-volume-davfs) plugin to enable WebDAV based mountable docker volumes for DavRODS.

- Install plugin

	```
	$ docker plugin install fentas/davfs
	```

## Usage

A script named `configure-for-davrods.sh` has been created to prepare the host environment for running the [SUMMA Test Cases](https://ral.ucar.edu/projects/summa) using a docker container named ~~`summa:local`~~ bartnijssen/summa:latest.

This script:

1. ~~builds the `summa:local` docker image from the [SUMMA source code in Gihtub](https://github.com/NCAR/summa)~~ Using default of [bartnijssen/summa:latest](https://hub.docker.com/r/bartnijssen/summa/) until build issues are resolved...
2. purges the local environment of containers, networks and volumes from prior runs
3. untars the test cases and modifies their run scripts to conform to use with iRODS and [docker-davrods](https://github.com/RENCI/docker-davrods)
4. installs an [iRODS 4.2.2 provider server](https://github.com/mjstealey/irods-provider-postgres) in docker, loads the SUMMA test case input data and prepares the output directories in iRODS space
5. installs a DavRODS server in docker and creates a `davrods-volume` that contains the contents of the appropriate user in iRODS to share with `summa:bionic` containers as they are run
6. displays information to the user as to how to run the test cases once the envirnment is prepared

**NOTE**: the `irods-provider` container will store it's configuration files and Vault in a local directory named `irods` via a host based volume mount. The SUMMA data can be observed at `summa-davrods/irods/var_irods/iRODS/Vault` as it's stored into iRODS.

Assuming the user has rights to run docker, the script is run as

```
$ ./configure-for-davrods.sh
```

- A full copy of the expected output from running `configure-for-davrods.sh` can be found at [logs/configure-for-davrods.log](logs/configure-for-davrods.log)

Once configuration is completed, the iRODS files can be observed in the DavRODS interface at: [http://localhost:8080/](http://localhost:8080/)

<img width="80%" alt="Initial setup" src="https://user-images.githubusercontent.com/5332509/36870226-622a35f2-1d6c-11e8-9e5f-f87f01f8bcac.png">

The test cases can then be run as:

```
$ cd summaTestCases_2.x
$ ./runTestCases_docker_davrods.sh
```

As the tests are run the output is written back to the `davrods-volume` mount which is connected to the `irods-provider` server via the `davrods-server` container. The resultant files can be observed both in the web browser as well as in iRODS directly via iCommands.

- In browser at [http://localhost:8080/output/wrrPaperTestCases/figure01/](http://localhost:8080/output/wrrPaperTestCases/figure01/)

<img width="80%" alt="Output results" src="https://user-images.githubusercontent.com/5332509/36870235-68da8cf8-1d6c-11e8-9329-44a70b437f59.png">

- In iRODS at `/tempZone/home/rods/output/wrrPaperTestCases/figure01`

	```
	$ docker exec -u irods irods-provider ils -Lr /tempZone/home/rods/output/wrrPaperTestCases/figure01
	/tempZone/home/rods/output/wrrPaperTestCases/figure01:
	  rods              0 demoResc           55 2018-03-01.20:47 & runinfo.txt
	        generic    /var/lib/irods/iRODS/Vault/home/rods/output/wrrPaperTestCases/figure01/runinfo.txt
	  rods              0 demoResc     29174436 2018-03-01.20:42 & vegImpactsRad_2005-07-01-00_spinup_riparianAspenBeersLaw_1.nc
	        generic    /var/lib/irods/iRODS/Vault/home/rods/output/wrrPaperTestCases/figure01/vegImpactsRad_2005-07-01-00_spinup_riparianAspenBeersLaw_1.nc
	  rods              0 demoResc     29174440 2018-03-01.20:46 & vegImpactsRad_2005-07-01-00_spinup_riparianAspenCLM2stream_1.nc
	        generic    /var/lib/irods/iRODS/Vault/home/rods/output/wrrPaperTestCases/figure01/vegImpactsRad_2005-07-01-00_spinup_riparianAspenCLM2stream_1.nc
	  rods              0 demoResc     29174440 2018-03-01.20:43 & vegImpactsRad_2005-07-01-00_spinup_riparianAspenNLscatter_1.nc
	        generic    /var/lib/irods/iRODS/Vault/home/rods/output/wrrPaperTestCases/figure01/vegImpactsRad_2005-07-01-00_spinup_riparianAspenNLscatter_1.nc
	  rods              0 demoResc     29174440 2018-03-01.20:45 & vegImpactsRad_2005-07-01-00_spinup_riparianAspenUEB2stream_1.nc
	        generic    /var/lib/irods/iRODS/Vault/home/rods/output/wrrPaperTestCases/figure01/vegImpactsRad_2005-07-01-00_spinup_riparianAspenUEB2stream_1.nc
	  rods              0 demoResc    145207928 2018-03-01.20:48 & vegImpactsRad_2005-07-01-00_spinup_riparianAspenVegParamPerturb_1.nc
	        generic    /var/lib/irods/iRODS/Vault/home/rods/output/wrrPaperTestCases/figure01/vegImpactsRad_2005-07-01-00_spinup_riparianAspenVegParamPerturb_1.nc
	  rods              0 demoResc     30511044 2018-03-01.20:42 & vegImpactsRad_2005-2006_riparianAspenBeersLaw_1.nc
	        generic    /var/lib/irods/iRODS/Vault/home/rods/output/wrrPaperTestCases/figure01/vegImpactsRad_2005-2006_riparianAspenBeersLaw_1.nc
	  rods              0 demoResc     30511048 2018-03-01.20:46 & vegImpactsRad_2005-2006_riparianAspenCLM2stream_1.nc
	        generic    /var/lib/irods/iRODS/Vault/home/rods/output/wrrPaperTestCases/figure01/vegImpactsRad_2005-2006_riparianAspenCLM2stream_1.nc
	  rods              0 demoResc     30511048 2018-03-01.20:43 & vegImpactsRad_2005-2006_riparianAspenNLscatter_1.nc
	        generic    /var/lib/irods/iRODS/Vault/home/rods/output/wrrPaperTestCases/figure01/vegImpactsRad_2005-2006_riparianAspenNLscatter_1.nc
	  rods              0 demoResc     30511048 2018-03-01.20:45 & vegImpactsRad_2005-2006_riparianAspenUEB2stream_1.nc
	        generic    /var/lib/irods/iRODS/Vault/home/rods/output/wrrPaperTestCases/figure01/vegImpactsRad_2005-2006_riparianAspenUEB2stream_1.nc
	  rods              0 demoResc    150003992 2018-03-01.20:50 & vegImpactsRad_2005-2006_riparianAspenVegParamPerturb_1.nc
	        generic    /var/lib/irods/iRODS/Vault/home/rods/output/wrrPaperTestCases/figure01/vegImpactsRad_2005-2006_riparianAspenVegParamPerturb_1.nc
	  rods              0 demoResc     30511044 2018-03-01.20:43 & vegImpactsRad_2006-2007_riparianAspenBeersLaw_1.nc
	        generic    /var/lib/irods/iRODS/Vault/home/rods/output/wrrPaperTestCases/figure01/vegImpactsRad_2006-2007_riparianAspenBeersLaw_1.nc
	  rods              0 demoResc     30511048 2018-03-01.20:47 & vegImpactsRad_2006-2007_riparianAspenCLM2stream_1.nc
	        generic    /var/lib/irods/iRODS/Vault/home/rods/output/wrrPaperTestCases/figure01/vegImpactsRad_2006-2007_riparianAspenCLM2stream_1.nc
	  rods              0 demoResc     30511048 2018-03-01.20:44 & vegImpactsRad_2006-2007_riparianAspenNLscatter_1.nc
	        generic    /var/lib/irods/iRODS/Vault/home/rods/output/wrrPaperTestCases/figure01/vegImpactsRad_2006-2007_riparianAspenNLscatter_1.nc
	  rods              0 demoResc     30511048 2018-03-01.20:45 & vegImpactsRad_2006-2007_riparianAspenUEB2stream_1.nc
	        generic    /var/lib/irods/iRODS/Vault/home/rods/output/wrrPaperTestCases/figure01/vegImpactsRad_2006-2007_riparianAspenUEB2stream_1.nc
	  rods              0 demoResc    150003992 2018-03-01.20:51 & vegImpactsRad_2006-2007_riparianAspenVegParamPerturb_1.nc
	        generic    /var/lib/irods/iRODS/Vault/home/rods/output/wrrPaperTestCases/figure01/vegImpactsRad_2006-2007_riparianAspenVegParamPerturb_1.nc
	  rods              0 demoResc     30511248 2018-03-01.20:43 & vegImpactsRad_2007-2008_riparianAspenBeersLaw_1.nc
	        generic    /var/lib/irods/iRODS/Vault/home/rods/output/wrrPaperTestCases/figure01/vegImpactsRad_2007-2008_riparianAspenBeersLaw_1.nc
	  rods              0 demoResc     30511252 2018-03-01.20:47 & vegImpactsRad_2007-2008_riparianAspenCLM2stream_1.nc
	        generic    /var/lib/irods/iRODS/Vault/home/rods/output/wrrPaperTestCases/figure01/vegImpactsRad_2007-2008_riparianAspenCLM2stream_1.nc
	  rods              0 demoResc     30511252 2018-03-01.20:44 & vegImpactsRad_2007-2008_riparianAspenNLscatter_1.nc
	        generic    /var/lib/irods/iRODS/Vault/home/rods/output/wrrPaperTestCases/figure01/vegImpactsRad_2007-2008_riparianAspenNLscatter_1.nc
	  rods              0 demoResc     30511252 2018-03-01.20:45 & vegImpactsRad_2007-2008_riparianAspenUEB2stream_1.nc
	        generic    /var/lib/irods/iRODS/Vault/home/rods/output/wrrPaperTestCases/figure01/vegImpactsRad_2007-2008_riparianAspenUEB2stream_1.nc
	  rods              0 demoResc    150004724 2018-03-01.20:53 & vegImpactsRad_2007-2008_riparianAspenVegParamPerturb_1.nc
	        generic    /var/lib/irods/iRODS/Vault/home/rods/output/wrrPaperTestCases/figure01/vegImpactsRad_2007-2008_riparianAspenVegParamPerturb_1.nc
	```

- A full copy of the expected output from running `runTestCases_docker_davrods.sh` can be found in [logs/runTestCases\_docker\_davrods.log](logs/runTestCases_docker_davrods.log)

## References

1. SUMMA - Structure for Unifying Multiple Modeling Alternatives: [http://www.ral.ucar.edu/projects/summa](http://www.ral.ucar.edu/projects/summa)
2. DavRODS - An Apache WebDAV interface to iRODS: [https://github.com/UtrechtUniversity/davrods](https://github.com/UtrechtUniversity/davrods)
3. iRODS - The Integrated Rule-Oriented Data System: [https://irods.org](https://irods.org)
4. Docker plugin docker-volume-davfs: [https://github.com/fentas/docker-volume-davfs](https://github.com/fentas/docker-volume-davfs)

