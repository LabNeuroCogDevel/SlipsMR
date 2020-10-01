cd /Volumes/Hera/Raw/BIDS/Pilots/SOA

mkdir -p sub-MM/anat/
niinote sub-MM/anat/sub-MM_T1w.nii.gz dcm2niix -o sub-MM/anat/ -f sub-MM_T1w ../../../MRprojects/Pilots/SOA/MATT/ABCD_T1w_MPR_vNav_256x256.5/

mkdir sub-MM/func
niinote sub-MM/func/sub-MM_task-ID_bold.nii.gz dcm2niix -o sub-MM/func/ -f sub-MM_task-ID_bold ../../../MRprojects/Pilots/SOA/MATT/ABCD_fMRI_task_stop_720x720.8
niinote sub-MM/func/sub-MM_task-OD_bold.nii.gz dcm2niix -o sub-MM/func/ -f sub-MM_task-OD_bold ../../../MRprojects/Pilots/SOA/MATT/ABCD_fMRI_task_stop_720x720.10
niinote sub-MM/func/sub-MM_task-SOA_bold.nii.gz dcm2niix -o sub-MM/func/ -f sub-MM_task-SOA_bold ../../../MRprojects/Pilots/SOA/MATT/ABCD_fMRI_task_stop_720x720.12
niinote sub-MM/func/sub-MM_task-DD_bold.nii.gz dcm2niix -o sub-MM/func/ -f sub-MM_task-DD_bold ../../../MRprojects/Pilots/SOA/MATT/ABCD_fMRI_task_stop_720x720.14

cd /Volumes/Hera/preproc/SOA
lncdprep /Volumes/Hera/Raw/BIDS/Pilots/SOA/ . --onlyt1
lncdprep /Volumes/Hera/Raw/BIDS/Pilots/SOA/ .
