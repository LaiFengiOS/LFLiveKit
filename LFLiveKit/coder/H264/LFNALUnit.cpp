
//
// NALUnit.cpp
//
// Implementation of Basic parsing of H.264 NAL Units
//
// Geraint Davies, March 2004
//
// Copyright (c) GDCL 2004-2008 http://www.gdcl.co.uk/license.htm



#include "LFNALUnit.h"


// --- core NAL Unit implementation ------------------------------

LFNALUnit::LFNALUnit()
    : m_pStart(NULL),
    m_cBytes(0){
}

bool
LFNALUnit::GetStartCode(const BYTE *& pBegin, const BYTE *& pStart, int& cRemain){
    // start code is any number of 00 followed by 00 00 01
    // We need to record the first 00 in pBegin and the first byte
    // following the startcode in pStart.
    // if no start code is found, pStart and cRemain should be unchanged.

    const BYTE *pThis = pStart;
    int cBytes = cRemain;

    pBegin = NULL;
    while (cBytes >= 4) {
        if (pThis[0] == 0) {
            // remember first 00
            if (pBegin == NULL) {
                pBegin = pThis;
            }
            if ((pThis[1] == 0) &&
                (pThis[2] == 1)) {
                // point to type byte of NAL unit
                pStart = pThis + 3;
                cRemain = cBytes - 3;
                return true;
            }
        } else {
            pBegin = NULL;
        }
        cBytes--;
        pThis++;
    }
    return false;
}

bool
LFNALUnit::Parse(const BYTE *pBuffer, int cSpace, int LengthSize, bool bEnd){
    // if we get the start code but not the whole
    // NALU, we can return false but still have the length property valid
    m_cBytes = 0;

    ResetBitstream();

    if (LengthSize > 0) {
        m_pStartCodeStart = pBuffer;

        if (LengthSize > cSpace) {
            return false;
        }

        m_cBytes = 0;
        for (int i = 0; i < LengthSize; i++) {
            m_cBytes <<= 8;
            m_cBytes += *pBuffer++;
        }

        if ((m_cBytes+LengthSize) <= cSpace) {
            m_pStart = pBuffer;
            return true;
        }
    } else {
        // this is not length-delimited: we must look for start codes
        const BYTE *pBegin;
        if (GetStartCode(pBegin, pBuffer, cSpace)) {
            m_pStart = pBuffer;
            m_pStartCodeStart = pBegin;

            // either we find another startcode, or we continue to the
            // buffer end (if this is the last block of data)
            if (GetStartCode(pBegin, pBuffer, cSpace)) {
                m_cBytes = int(pBegin - m_pStart);
                return true;
            } else if (bEnd) {
                // current element extends to end of buffer
                m_cBytes = cSpace;
                return true;
            }
        }
    }
    return false;
}

// bitwise access to data
void
LFNALUnit::ResetBitstream(){
    m_idx = 0;
    m_nBits = 0;
    m_cZeros = 0;
}

void
LFNALUnit::Skip(int nBits){
    if (nBits < m_nBits) {
        m_nBits -= nBits;
    } else {
        nBits -= m_nBits;
        while (nBits >= 8) {
            GetBYTE();
            nBits -= 8;
        }
        if (nBits) {
            m_byte = GetBYTE();
            m_nBits = 8;

            m_nBits -= nBits;
        }
    }
}

// get the next byte, removing emulation prevention bytes
BYTE
LFNALUnit::GetBYTE(){
    if (m_idx >= m_cBytes) {
        return 0;
    }

    BYTE b = m_pStart[m_idx++];

    // to avoid start-code emulation, a byte 0x03 is inserted
    // after any 00 00 pair. Discard that here.
    if (b == 0) {
        m_cZeros++;
        if ((m_idx < m_cBytes) && (m_cZeros == 2) && (m_pStart[m_idx] == 0x03)) {
            m_idx++;
            m_cZeros = 0;
        }
    } else {
        m_cZeros = 0;
    }
    return b;
}

unsigned long
LFNALUnit::GetBit(){
    if (m_nBits == 0) {
        m_byte = GetBYTE();
        m_nBits = 8;
    }
    m_nBits--;
    return (m_byte >> m_nBits) & 0x1;
}

unsigned long
LFNALUnit::GetWord(int nBits){
    unsigned long u = 0;
    while (nBits > 0) {
        u <<= 1;
        u |= GetBit();
        nBits--;
    }
    return u;
}

unsigned long
LFNALUnit::GetUE(){
    // Exp-Golomb entropy coding: leading zeros, then a one, then
    // the data bits. The number of leading zeros is the number of
    // data bits, counting up from that number of 1s as the base.
    // That is, if you see
    //      0001010
    // You have three leading zeros, so there are three data bits (010)
    // counting up from a base of 111: thus 111 + 010 = 1001 = 9
    int cZeros = 0;
    while (GetBit() == 0) {
        cZeros++;
    }
    return GetWord(cZeros) + ((1 << cZeros)-1);
}

long
LFNALUnit::GetSE(){
    // same as UE but signed.
    // basically the unsigned numbers are used as codes to indicate signed numbers in pairs
    // in increasing value. Thus the encoded values
    //      0, 1, 2, 3, 4
    // mean
    //      0, 1, -1, 2, -2 etc

    unsigned long UE = GetUE();
    bool bPositive = UE & 1;
    long SE = (UE + 1) >> 1;
    if (!bPositive) {
        SE = -SE;
    }
    return SE;
}

// --- sequence params parsing ---------------
LFSeqParamSet::LFSeqParamSet()
    : m_cx(0),
    m_cy(0),
    m_FrameBits(0){
    // SetRect(&m_rcFrame, 0, 0, 0, 0);
}

void
ScalingList(int size, LFNALUnit *pnalu){
    long lastScale = 8;
    long nextScale = 8;
    for (int j = 0; j < size; j++) {
        if (nextScale != 0) {
            long delta = pnalu->GetSE();
            nextScale = (lastScale + delta + 256) %256;
        }
        int scaling_list_j = (nextScale == 0) ? (int)lastScale : (int)nextScale;
        lastScale = scaling_list_j;
    }
}

bool
LFSeqParamSet::Parse(LFNALUnit *pnalu){
    if (pnalu->Type() != LFNALUnit::NAL_Sequence_Params) {
        return false;
    }

    // with the UE/SE type encoding, we must decode all the values
    // to get through to the ones we want
    pnalu->ResetBitstream();
    pnalu->Skip(8);             // type
    m_Profile =(int) pnalu->GetWord(8);
    m_Compatibility = (BYTE)pnalu->GetWord(8);
    m_Level = (int)pnalu->GetWord(8);

    /*int seq_param_id =*/ pnalu->GetUE();

    if ((m_Profile == 100) || (m_Profile == 110) || (m_Profile == 122) || (m_Profile == 144)) {
        int chroma_fmt = (int)pnalu->GetUE();
        if (chroma_fmt == 3) {
            pnalu->Skip(1);
        }
        /* int bit_depth_luma_minus8 = */ pnalu->GetUE();
        /* int bit_depth_chroma_minus8 = */ pnalu->GetUE();
        pnalu->Skip(1);
        int seq_scaling_matrix_present = (int)pnalu->GetBit();
        if (seq_scaling_matrix_present) {
            for (int i = 0; i < 8; i++) {
                if (pnalu->GetBit()) {
                    if (i < 6) {
                        ScalingList(16, pnalu);
                    } else {
                        ScalingList(64, pnalu);
                    }
                }
            }
        }
    }

    int log2_frame_minus4 = (int)pnalu->GetUE();
    m_FrameBits = log2_frame_minus4 + 4;
    int POCtype = (int)pnalu->GetUE();
    if (POCtype == 0) {
        /*int log2_poc_minus4 =*/ pnalu->GetUE();
    } else if (POCtype == 1) {
        pnalu->Skip(1); // delta always zero
        /*int nsp_offset =*/ pnalu->GetSE();
        /*int nsp_top_to_bottom = */ pnalu->GetSE();
        int num_ref_in_cycle = (int)pnalu->GetUE();
        for (int i = 0; i < num_ref_in_cycle; i++) {
            /*int sf_offset =*/ pnalu->GetSE();
        }
    } else if (POCtype != 2) {
        return false;
    }
    // else for POCtype == 2, no additional data in stream

    /*int num_ref_frames =*/ pnalu->GetUE();
    /*int gaps_allowed =*/ pnalu->GetBit();

    int mbs_width = (int)pnalu->GetUE();
    int mbs_height = (int)pnalu->GetUE();
    m_cx = (mbs_width+1) * 16;
    m_cy = (mbs_height+1) * 16;

    // smoke test validation of sps
    if ((m_cx > 2000) || (m_cy > 2000)) {
        return false;
    }

    // if this is false, then sizes are field sizes and need adjusting
    m_bFrameOnly = pnalu->GetBit() ? true : false;

    if (!m_bFrameOnly) {
        pnalu->Skip(1); // adaptive frame/field
    }
    pnalu->Skip(1);     // direct 8x8

#if 0
    SetRect(&m_rcFrame, 0, 0, 0, 0);
    bool bCrop = pnalu->GetBit() ? true : false;
    if (bCrop) {
        // get cropping rect
        // store as exclusive, pixel parameters relative to frame
        m_rcFrame.left = pnalu->GetUE() * 2;
        m_rcFrame.right = pnalu->GetUE() * 2;
        m_rcFrame.top = pnalu->GetUE() * 2;
        m_rcFrame.bottom = pnalu->GetUE() * 2;
    }

    if (!IsRectEmpty(&m_rcFrame)) {
        m_rcFrame.right = m_cx - m_rcFrame.right;
        m_rcFrame.bottom = m_cy - m_rcFrame.bottom;
    }
#endif
    // adjust rect from 2x2 units to pixels

    if (!m_bFrameOnly) {
        // adjust heights from field to frame
        m_cy *= 2;
#if 0
        m_rcFrame.top *= 2;
        m_rcFrame.bottom *= 2;
#endif
    }

    // .. rest are not interesting yet
    m_nalu = *pnalu;
    return true;
}

// --- slice header --------------------
bool
LFSliceHeader::Parse(LFNALUnit *pnalu){
    switch (pnalu->Type()) {
    case LFNALUnit::NAL_IDR_Slice:
    case LFNALUnit::NAL_Slice:
    case LFNALUnit::NAL_PartitionA:
        // all these begin with a slice header
        break;

    default:
        return false;
    }

    // slice header has the 1-byte type, then one UE value,
    // then the frame number.
    pnalu->ResetBitstream();
    pnalu->Skip(8);     // NALU type
    pnalu->GetUE();     // first mb in slice
    pnalu->GetUE();     // slice type
    pnalu->GetUE();     // pic param set id

    m_framenum = (int)pnalu->GetWord(m_nBitsFrame);
    return true;
}

// --- SEI ----------------------


LFSEIMessage::LFSEIMessage(LFNALUnit *pnalu){
    m_pnalu = pnalu;
    const BYTE *p = pnalu->Start();
    p++;                // nalu type byte
    m_type = 0;
    while (*p == 0xff) {
        m_type += 255;
        p++;
    }
    m_type += *p;
    p++;
    m_length = 0;
    while (*p == 0xff) {
        m_type += 255;
        p++;
    }
    m_length += *p;
    p++;
    m_idxPayload = int(p - m_pnalu->Start());
}

LFavcCHeader::LFavcCHeader(const BYTE *header, int cBytes){
    if (cBytes < 8) {
        return;
    }
    const BYTE *pEnd = header + cBytes;

    int cSeq = header[5] & 0x1f;
    header += 6;
    for (int i = 0; i < cSeq; i++) {
        if ((header+2) > pEnd) {
            return;
        }
        int cThis = (header[0] << 8) + header[1];
        header += 2;
        if ((header+cThis) > pEnd) {
            return;
        }
        if (i == 0) {
            LFNALUnit n(header, cThis);
            m_sps = n;
        }
        header += cThis;
    }
    if ((header + 3) >= pEnd) {
        return;
    }
    int cPPS = header[0];
    if (cPPS > 0) {
        int cThis = (header[1] << 8) + header[2];
        header += 3;
        LFNALUnit n(header, cThis);
        m_pps = n;
    }
}

