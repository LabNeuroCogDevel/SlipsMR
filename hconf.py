import os
"""
run like
heudiconv -b -o /Volumes/Hera/Raw/BIDS/SlipsPilot -c dcm2niix -f hconf.py  -d '/Volumes/Hera/Raw/MRprojects/SlipsPilot/20*/{subject}_*/*/*'  -s $ID

N.B. hardlinked within/between bids/ and scripts/
"""


def create_key(template, outtype=('nii.gz',), annotation_classes=None):
    if template is None or not template:
        raise ValueError('Template must be a valid format string')
    return template, outtype, annotation_classes


def infotodict(seqinfo):
    """Heuristic evaluator for determining which runs belong where
    allowed template fields - follow python string module:
    item: index within category
    subject: participant id
    seqitem: run number during scanning
    subindex: sub index within group
    session: scan index for longitudinal acq
    """

    nii = ('nii.gz')

    t1 = create_key('sub-{subject}/anat/sub-{subject}_T1w', outtype=nii)
    fmapAP = create_key('sub-{subject}/fmap/sub-{subject}_dir-AP_epi', outtype=nii)
    fmapPA = create_key('sub-{subject}/fmap/sub-{subject}_dir-PA_epi', outtype=nii)
    # task
    ID = create_key('sub-{subject}/func/sub-{subject}_task-ID_bold', outtype=nii)
    OD = create_key('sub-{subject}/func/sub-{subject}_task-OD_bold', outtype=nii)
    SOA = create_key('sub-{subject}/func/sub-{subject}_task-SOA_bold', outtype=nii)
    DD = create_key('sub-{subject}/func/sub-{subject}_task-DD_bold', outtype=nii)
    # ref
    IDref = create_key('sub-{subject}/func/sub-{subject}_task-ID_sbref', outtype=nii)
    ODref = create_key('sub-{subject}/func/sub-{subject}_task-OD_sbref', outtype=nii)
    SOAref = create_key('sub-{subject}/func/sub-{subject}_task-SOA_sbref', outtype=nii)
    DDref = create_key('sub-{subject}/func/sub-{subject}_task-DD_sbref', outtype=nii)

    info = {t1: [],
            fmapAP: [], fmapPA: [],
            ID: [], OD: [], SOA: [], DD: [],
            IDref: [], ODref: [], SOAref: [], DDref: [], }
    for s in seqinfo:
        if (s.dim3 == 176) and (s.dim4 == 1) and ('MPRAGE' in s.protocol_name):
            info[t1] = [s.series_id]

        elif (s.dim4 == 2) and ('SpinEchoFieldMap_AP' in s.protocol_name):
            info[fmapAP] = [s.series_id]
        elif (s.dim4 == 2) and ('SpinEchoFieldMap_PA' in s.protocol_name):
            info[fmapPA] = [s.series_id]

        elif (s.dim4 >= 758) and ('ID' in s.protocol_name):
            info[ID] = [s.series_id]
        elif (s.dim4 == 1) and ('ID' in s.protocol_name) and ('SBRef' in s.dcm_dir_name):
            info[IDref] = [s.series_id]

        elif (s.dim4 >= 201) and ('OD' in s.protocol_name):
            info[OD] = [s.series_id]
        elif (s.dim4 == 1) and ('OD' in s.protocol_name) and ('SBRef' in s.dcm_dir_name):
            info[ODref] = [s.series_id]

        elif (s.dim4 >= 645) and ('SOA' in s.protocol_name):
            info[SOA] = [s.series_id]
        elif (s.dim4 == 1) and ('SOA' in s.protocol_name) and ('SBRef' in s.dcm_dir_name):
            info[SOAref] = [s.series_id]

        elif (s.dim4 >= 639) and ('DD' in s.protocol_name):
            info[DD] = [s.series_id]
        elif (s.dim4 == 1) and ('DD' in s.protocol_name) and ('SBRef' in s.dcm_dir_name):
            info[DDref] = [s.series_id]
    return info
