function finalizeProject(obj)
% FINALIZEPROJECT  Mark the whole project complete.
meta = obj.readMeta_();
meta.status   = 'complete';
meta.finished = datetime("now","Format","dd-MMM-uuuu HH:mm:ss");
obj.writeMeta_(meta);
fprintf('[DataMgr] Project "%s" marked complete.\n', obj.ProjectName);
end
