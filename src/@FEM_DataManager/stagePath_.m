function p = stagePath_(obj, stageIdx)
p = fullfile(obj.ProjectRoot_, 'stages', sprintf('stage_%02d', stageIdx));
end
