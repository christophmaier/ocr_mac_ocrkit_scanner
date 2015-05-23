#!/bin/bash
# 
# Automation: Connect to a remote scanner via SMB, then use OCRKit to OCR on scanned PDFs
# This script works for me, but is surely not an elegant, clever solution
# Drawbacks for example: 
# *Nearly no tests
# *Clumsy filenames and directories to make sure nothing gets overwritten
# *Original files aren't deleted in case sth. goes wrong; have to clean up manually
# *Too many log entries
# *Would require SleepWatcher to run on each wakeup (instead of regularly via crontab)



#------------
# 0 Variables
#------------

# Some variables
ocr_homedir=/Volumes/OSX/Users/demo/Documents/pdf/incoming # home of all PDFs
ocr_mountpoint=$ocr_homedir"/smb_epson" # where to mount he remote scanner via smb
ocr_directory=$ocr_mountpoint"/EPSCAN/001" # subdirectory of the scanner in which the scans reside
ocr_rundir=$ocr_directory"/"`date +%Y%m%d_%HH_%mM_%SS` #create a directory for each succesful iteration
ocr_logfile=$ocr_homedir"/ocr.log"
ocr_sourcefilenumber="" # number of files to work with
ocr_target="" # If 0, the all ocr'd files will be copied to the hdd
ocr_sourcefile="" #pdf-file to be processed


# Path, file and parameters of OCRKit
# Demo available from http://ocrkit.com/download.html - Full verson costs 50 Euro
ocrkit_pdf="/Volumes/OSX/Applications/OCRKit.app/Contents/MacOS/OCRkit --lang de --format pdf --no-progress --output"


#------------
# 1 "Debug" 
#------------
# Set $ocr_rundir static to omit creation of new folders while developing
# ocr_rundir=$ocr_directory"/2015_05_17_16H_05M_42S"
# move one file to main folder 
# cd $ocr_rundir
# mv EPSON002.PDF ..

#------------
# 2 Functions
#------------

ocr_mount()
{
echo "+++++++++++++++++++++++++++++++++++++++++" >> $ocr_logfile
if test -d $ocr_mountpoint"/EPSCAN"
then
	echo "`DATE`: $ocr_mountpoint already mounted" >> $ocr_logfile
else
	mount -t smbfs //guest:guest@epson/MEMORYCARD $ocr_mountpoint >> $ocr_logfile
	echo "`DATE`: $ocr_mountpoint mounted" >> $ocr_logfile
fi
return
}

ocr_prepare()
{
echo "`DATE`: ocr_prepare() starting"  >> $ocr_logfile

# How many files to work on are there?
ocr_sourcefilenumber="`ls -1 EPSON* | wc -l | awk '{print $1}'`"
if test $ocr_sourcefilenumber -ge 1
then
	echo "`DATE`: $ocr_sourcefilenumber PDFs to work on; continuing" >> $ocr_logfile
	# Make Directory, move files
	mkdir $ocr_rundir
	mv $ocr_directory"/EPSON"*\."PDF" $ocr_rundir"/"
	

else
	echo "`DATE`: $ocr_sourcefilenumber PDFs to work on; quitting" >> $ocr_logfile
	goodbye
fi
echo "`DATE`: ocr_prepare() finished"  >> $ocr_logfile
return
}

ocr_sourcefilebyfile()
{
echo "`DATE`: function ocr_sourcefilebyfile started" >> $ocr_logfile
# Make sure we're in the right directory
cd $ocr_rundir

#Thanks to http://superuser.com/questions/660437/linux-run-command-on-a-batch-of-files-with-matching-output-files 
for ocr_sourcefile in "EPSON"???\."PDF";
do
	echo "Processing $ocr_sourcefile right now" >> $ocr_logfile
	ocr_targetfile=${ocr_sourcefile/\.PDF/"-OCR.PDF"} #Attach -OCR to Filename
	ocr_targetfile=`date +%Y%m%d_%H%M_%SS`"_$ocr_targetfile" #Make Name Unique (to get rid of the subfolders later)
	$ocrkit_pdf $ocr_targetfile $ocr_sourcefile
	echo "OCR Target Filename: $ocr_targetfile"  >> $ocr_logfile
	echo ""
done

echo "`DATE`: function ocr_sourcefilebyfile finished" >> $ocr_logfile
return
}

ocr_copyfiles()
{
# Is the target for the OCR-File local or remote?
# Look for -emtpy- file ocr_target_hdd.conf in $ocr_directory on sd card on scanner
# If ocr_target_hdd.conf exists, copy files to local folder, in any other case=keep on local hdd

test -f $ocr_directory"/ocr_target_hdd.conf"
ocr_target=$?
if [ $ocr_target -eq 0 ]

# Move ocr'd files incl. directory to local folder
then
	# Cleanup: Remove source files
	# Not a great idea right now. Maybe if script is better tested.
	# rm EPSON???\.PDF
	
	echo "`DATE`: ocr_copyfiles(): Moving Directory"  >> $ocr_logfile
	mv $ocr_rundir $ocr_homedir

# Everything else: do nothing. proceed to unmount
else
	echo "`DATE`: ocr_copyfiles(): Keeping files local." >> $ocr_logfile
fi

echo "`DATE`: ocr_copyfiles(): finished" >> $ocr_logfile
return
}

goodbye()
{
# unmount if finished
cd $ocr_homedir
sleep 1
umount $ocr_mountpoint
echo "`DATE`: $ocr_mountpoint unmounted" >> $ocr_logfile
exit 1
return
}

#------------
# 3 Run it
#------------

ocr_mount
ocr_prepare #incl. goodbye(), if there's nothing to do
ocr_sourcefilebyfile
ocr_copyfiles
goodbye
