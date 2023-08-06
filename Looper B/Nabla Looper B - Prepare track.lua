function toggleTrackConfigurations()
    local trackCount = reaper.CountSelectedTracks(0)
    for i = 0, trackCount - 1 do
        local track = reaper.GetSelectedTrack(0, i)
        local recmonitems = reaper.GetMediaTrackInfo_Value(track, 'I_RECMONITEMS')
        local freemode = reaper.GetMediaTrackInfo_Value(track, 'B_FREEMODE')
        recmonitems = 1 - recmonitems
        freemode = 1 - freemode
        reaper.SetMediaTrackInfo_Value(track, 'I_RECMONITEMS', recmonitems)
        reaper.SetMediaTrackInfo_Value(track, 'B_FREEMODE', freemode)
    end
end

toggleTrackConfigurations()

