function saveState(obj, Pre, Sol, options)
% SAVESTATE  Legacy interface — wraps saveSnapshot.
fprintf('[DataMgr] saveState() called (legacy). Use saveSnapshot().\n');
obj.saveSnapshot(Pre, Sol, options);
end