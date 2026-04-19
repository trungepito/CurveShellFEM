function assert_equal(a, b, tol, msg)
% ASSERT_EQUAL  Assert |a - b| <= tol element-wise. Throws on failure.
if nargin < 3, tol = 0; end
if nargin < 4, msg = ''; end
diff = max(abs(a(:) - b(:)));
if diff > tol
    if isempty(msg)
        error('AssertEqual:failed', ...
              'Expected |a-b| <= %g, got %g', tol, diff);
    else
        error('AssertEqual:failed', '%s: expected |a-b| <= %g, got %g', ...
              msg, tol, diff);
    end
end
end
