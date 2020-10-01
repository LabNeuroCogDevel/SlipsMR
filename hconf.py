import os
"""
heudiconv config file implementing 'infotodict'
run like
heudiconv -b -o /Volumes/Hera/Raw/BIDS/SlipsPilot -c dcm2niix -f hconf.py  -d '/Volumes/Hera/Raw/MRprojects/SlipsPilot/20*/{subject}_*/*/*'  -s $ID

N.B. hardlinked within/between bids/ and scripts/
"""


def create_key(modality, fname, outtype=('nii.gz',), annotation_classes=None):
    template = "sub-{subject}/%s/sub-{subject}_%s" % (modality, fname)
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

    t1 = create_key('anat', 'T1w')
    fmapAP = create_key('fmap', 'dir-AP_epi')
    fmapPA = create_key('fmap', 'dir-PA_epi')
    # task
    ID = create_key('func', 'task-ID_bold')
    OD = create_key('func', 'task-OD_bold')
    SOA = create_key('func', 'task-SOA_bold')
    DD = create_key('func', 'task-DD_bold')
    # ref
    IDref = create_key('func', 'task-ID_sbref')
    ODref = create_key('func', 'task-OD_sbref')
    SOAref = create_key('func', 'task-SOA_sbref')
    DDref = create_key('func', 'task-DD_sbref')

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
