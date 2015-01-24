###
  * Copyright (c) 2011, iSENSE Project. All rights reserved.
  *
  * Redistribution and use in source and binary forms, with or without
  * modification, are permitted provided that the following conditions are met:
  *
  * Redistributions of source code must retain the above copyright notice, this
  * list of conditions and the following disclaimer. Redistributions in binary
  * form must reproduce the above copyright notice, this list of conditions and
  * the following disclaimer in the documentation and/or other materials
  * provided with the distribution. Neither the name of the University of
  * Massachusetts Lowell nor the names of its contributors may be used to
  * endorse or promote products derived from this software without specific
  * prior written permission.
  *
  * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
  * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
  * ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE FOR
  * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
  * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
  * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
  * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
  * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
  * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
  * DAMAGE.
  *
###
$ ->
  if namespace.controller is "visualizations" and
  namespace.action in ["displayVis", "embedVis", "show"]

    # Regression Types
    # Regression functions are listed with their partial derrivitives, eg.
    #
    # [f(x,Ps), f(x,Ps) dPs[0], f(x,Ps) dPs[1] ,... , f(x,Ps) dPs[dPs.length]]
    window.globals ?= {}
    globals.REGRESSION ?= {}

    globals.REGRESSION.FUNCS = []
    globals.REGRESSION.DENORM_FUNCS = []

    globals.REGRESSION.LINEAR = globals.REGRESSION.FUNCS.length
    globals.REGRESSION.FUNCS.push [
      (x, P) -> P[0] + (x * P[1]),
      (x, P) -> 1,
      (x, P) -> x]

    globals.REGRESSION.QUADRATIC = globals.REGRESSION.FUNCS.length
    globals.REGRESSION.FUNCS.push [
      (x, P) -> P[0] + (x * P[1]) + (x * x * P[2])
      (x, P) -> 1
      (x, P) -> x
      (x, P) -> x * x]

    globals.REGRESSION.CUBIC = globals.REGRESSION.FUNCS.length
    globals.REGRESSION.FUNCS.push [
      (x, P) -> P[0] + (x * P[1]) + (x * x * P[2]) + (x * x * x * P[3]),
      (x, P) -> 1,
      (x, P) -> x,
      (x, P) -> x * x,
      (x, P) -> x * x * x]

    globals.REGRESSION.EXPONENTIAL = globals.REGRESSION.FUNCS.length
    globals.REGRESSION.FUNCS.push [
      (x, P) -> P[0] + Math.exp(P[1] * x + P[2]),
      (x, P) -> 1,
      (x, P) -> x * Math.exp(P[1] * x + P[2]),
      (x, P) -> Math.exp(P[1] * x + P[2])]
    
    globals.REGRESSION.LOGARITHMIC = globals.REGRESSION.FUNCS.length
    globals.REGRESSION.FUNCS.push [
      (x, P) -> P[0] + Math.log(P[1] * x + P[2]),
      (x, P) -> 1,
      (x, P) -> x / (P[1] * x + P[2]),
      (x, P) -> 1 / (P[1] * x + P[2])]

    globals.REGRESSION.NUM_POINTS = 200

    ###
    Calculates a regression and returns it as a highcharts series.
    ###
    globals.getRegression = (xs, ys, type, xBounds, seriesName, dashStyle) ->
      Ps = []
      func = globals.REGRESSION.FUNCS[type]
      
      # Make an initial Estimate
      switch type

        when globals.REGRESSION.LINEAR
          Ps = [1,1]

        when globals.REGRESSION.QUADRATIC
          Ps = [1,1,1]

        when globals.REGRESSION.CUBIC
          Ps = [1,1,1,1]

        when globals.REGRESSION.EXPONENTIAL
          Ps = [1,1,1]

        when globals.REGRESSION.LOGARITHMIC
          # We want to avoid starting with a guess that takes the log of a negative number
          Ps = [1,1,Math.min.apply(null, xs) + 1]
      
      # Get the new Ps
      [Ps, R2] = NLLS(func, normalizeData(xs, type), ys, Ps)
      
      # Create the highcharts series
      generateHighchartsSeries(Ps, R2, type, xBounds, seriesName, dashStyle)

    ###
    Returns a series object to draw on the chart canvas.
    ###
    generateHighchartsSeries = (Ps, R2, type, xBounds, seriesName, dashStyle) ->
      data = for i in [0..globals.REGRESSION.NUM_POINTS]
        xv = (i / globals.REGRESSION.NUM_POINTS) #* ((normalizeData(xBounds.dataMax) - normalizeData(xBounds.dataMin)) + normalizeData(xBounds.dataMin))
        yv = 0
        if type == globals.REGRESSION.LOGARITHMIC
          if globals.curVis.canvas == 'timeline_canvas'
            yv = calculateRegressionPoint(Ps, xv, type)
          else
            yv = calculateRegressionPoint(Ps, xv * (xBounds.dataMax - xBounds.dataMin) + xBounds.dataMin, type)
        else
          yv = calculateRegressionPoint(Ps, xv + 1, type)
        {x: xv * (xBounds.dataMax - xBounds.dataMin) + xBounds.dataMin, y: yv}
      Ps = visSpaceParameters(Ps, xBounds, type)
      str = makeToolTip(Ps, R2, type, seriesName)

      ret =
        name:
          id: ''
          group: seriesName
          regression:
            tooltip: str
        data: data
        type: 'line'
        color: '#000'
        lineWidth: 2
        dashStyle: dashStyle
        showInLegend: 0
        marker:
          symbol: 'blank'
        states:
          hover:
            lineWidth: 4
      
    ###
    Uses the regression matrix to calculate the y value given an x value.
    ###
    calculateRegressionPoint = (Ps, x, type) ->
      globals.REGRESSION.FUNCS[type][0](x, Ps)
      
    ###
    Returns tooltip description of the regression.
    ###
    makeToolTip = (Ps, R2, type, seriesName) ->

      # Format parameters for output
      Ps = Ps.map roundToFourSigFigs

      ret = switch type

        when globals.REGRESSION.LINEAR
          """
          <div class="regressionTooltip"> #{seriesName} </div>
          <br>
          <strong>
            f(x) = #{Ps[1]}x + #{Ps[0]}
          </strong>
          """
        when globals.REGRESSION.QUADRATIC
          """
          <div class="regressionTooltip"> #{seriesName} </div>
          <br>
          <strong>
            f(x) = #{Ps[2]}x<sup>2</sup> + #{Ps[1]}x + #{Ps[0]}
          </strong>
          """
        when globals.REGRESSION.CUBIC
          """
          <div class="regressionTooltip"> #{seriesName} </div>
          <br>
          <strong>
            f(x) = #{Ps[3]}x<sup>3</sup> + #{Ps[2]}x<sup>2</sup> + #{Ps[1]}x + #{Ps[0]}
          </strong>
          """
        when globals.REGRESSION.EXPONENTIAL
          """
          <div class="regressionTooltip"> #{seriesName} </div>
          <br>
          <strong>
            f(x) = e<sup>(#{Ps[1]}x + #{Ps[2]})</sup> + #{Ps[0]}
          </strong>
          """

        when globals.REGRESSION.LOGARITHMIC
          """
          <div class="regressionTooltip"> #{seriesName} </div>
          <br>
          <strong>
            f(x) = ln(#{Ps[1]}x + #{Ps[2]}) + #{Ps[0]}
          </strong>
          """

      ret += """
      <br>
      <strong> R <sup>2</sup> = </strong> #{roundToFourSigFigs R2}
      """

    ###
    Round the current float value to 4 significant figures.
    I keep this in a separate function because we weren't sure this was the best implemenation.
    ###
    roundToFourSigFigs = (float) ->
      return float.toPrecision(4)

    ###
    Calculates the jacobian of the given x over the given parameters using
    a set of partial derrivitive functions as given at the top of this file.
    ###
    jacobian = (func, xs, Ps) ->
      jac = []

      res = for x in xs
        for P,Pindex in Ps
          func[Pindex + 1](x, Ps)

    ###
    Newton-Gauss non-linear least squares regression using shift-cutting

      MAX_ITER       - Maximum number of iterations before termination.
      SHIFT_CUT_DOWN - Shift cut fraction used when divergence occurs.
      SHIFT_CUT_UP   - Fraction used to increase shift size if no divergence occurs.
      THRESH         - Threshold of error change, terminates algorithm early if met.

      func - Array of function, function to be fit followed by its partial derrivitives.
      xs   - Array of x values
      ys   - Array of y values (ground truth)
      Ps   - Array of initial parameter estimates.
    ###
    NLLS_MAX_ITER = 1000
    NLLS_SHIFT_CUT_DOWN = 0.9
    NLLS_SHIFT_CUT_UP = 1.1
    NLLS_THRESH = 1e-10
    NLLS = (func, xs, ys, Ps) ->
      prevErr = Infinity
      shiftCut = 1
      for iter in [1..NLLS_MAX_ITER]
        # Iterate
        dPs = iterateNLLS(func, xs, ys, Ps)
        nextPs = numeric.add(Ps, numeric.mul(dPs, shiftCut))
        nextErr = sqe(func, xs, ys, nextPs)

        if prevErr < nextErr or isNaN(nextErr)
          # If the iteration has diverged (or failed), line search a shift cut
          lsIters = 0
          while prevErr < nextErr or isNaN(nextErr)
            # If we line search too long and can't find a valid value
            # Then we declare the regression to have failed and throw.
            lsIters += 1
            if lsIters > 500
              throw new Error()

            shiftCut *= NLLS_SHIFT_CUT_DOWN
            nextPs = numeric.add(Ps, numeric.mul(dPs, shiftCut))
            nextErr = sqe(func, xs, ys, nextPs)
        else
          # Otherwise, accelerate towards optimum
          shiftCut = Math.min(shiftCut * NLLS_SHIFT_CUT_UP, 1)

        Ps = nextPs

        # Break early if the error ratio has dropped below the threshold
        if (prevErr - nextErr) / prevErr < NLLS_THRESH
          break

        prevErr = nextErr

      # Calculate R^2 value
      mean = numeric.sum(ys) / ys.length
      SStot = numeric.sum(ys.map((y) -> (y - mean) * (y - mean)))
      R2 = (1 - prevErr / SStot)

      [Ps, R2]

    ###
    Inner loop of Newton-gauss method
    ###
    iterateNLLS = (func, xs, ys, Ps) ->
      residuals = numeric.sub(ys, xs.map((x) -> func[0](x, Ps)))
      jac = jacobian(func, xs, Ps)
      jacT = numeric.transpose jac
      
      # dP = (JT*J)^-1 * JT * r
      deltaPs = numeric.dot(numeric.dot(numeric.inv(numeric.dot(jacT, jac)),
        jacT),
        residuals)

    ###
    Calculates the current squared error for the given function, parameters and ground truth.
    ###
    sqe = (func, xs, ys, Ps) ->
      numeric.sum(numeric.sub(ys, xs.map((x) -> func[0](x, Ps))).map (x) -> x * x)

    ###
    Denormalize functions given Ps, the mean and sigma.
    ###
    # Linear
    globals.REGRESSION.DENORM_FUNCS.push [
      (Ps, mean, sigma) -> Ps[0] - Ps[1] * mean / sigma,
      (Ps, mean, sigma) -> Ps[1] / sigma
    ]
    # Quadratic
    globals.REGRESSION.DENORM_FUNCS.push [
      (Ps, mean, sigma) ->
        globals.REGRESSION.DENORM_FUNCS[globals.REGRESSION.LINEAR][0](Ps, mean, sigma) \
        + (Ps[2] * Math.pow(mean, 2)) / Math.pow(sigma, 2)
      (Ps, mean, sigma) ->
        globals.REGRESSION.DENORM_FUNCS[globals.REGRESSION.LINEAR][1](Ps, mean, sigma) \
        - (Ps[2] * 2 * mean) / Math.pow(sigma, 2)
      (Ps, mean, sigma) -> (Ps[2] / Math.pow(sigma, 2))
    ]
    # Cubic
    globals.REGRESSION.DENORM_FUNCS.push [
      (Ps, mean, sigma) ->
        globals.REGRESSION.DENORM_FUNCS[globals.REGRESSION.QUADRATIC][0](Ps, mean, sigma) \
        - Ps[3] * Math.pow(mean, 3) / Math.pow(sigma, 3)
      (Ps, mean, sigma) ->
        globals.REGRESSION.DENORM_FUNCS[globals.REGRESSION.QUADRATIC][1](Ps, mean, sigma) \
        + Ps[3] * 3 * Math.pow(mean, 2) / Math.pow(sigma, 3)
      (Ps, mean, sigma) ->
        globals.REGRESSION.DENORM_FUNCS[globals.REGRESSION.QUADRATIC][2](Ps, mean, sigma) \
        - Ps[3] * 3 * mean / Math.pow(sigma, 3)
      (Ps, mean, sigma) -> Ps[3] / Math.pow(sigma, 3)
    ]
    # Exponential
    globals.REGRESSION.DENORM_FUNCS.push [
      (Ps, mean, sigma) -> Ps[0],
      (Ps, mean, sigma) -> Ps[1] / sigma,
      (Ps, mean, sigma) -> Ps[2] - (Ps[1] * mean) / sigma
    ]
    # Logarithmic
    globals.REGRESSION.DENORM_FUNCS.push [
      (Ps, mean, sigma) -> Ps[0] + Ps[1] * Math.log(1 / sigma),
      (Ps, mean, sigma) -> Ps[1],
      (Ps, mean, sigma) -> Ps[2] * sigma - mean
    ]

    # Calculate the average
    calculateMean = (points) ->
      mean = 0
      for point in points
        mean += point / points.length
      mean

    # Normalize
    normalizeData = (points, type) ->
      max = Math.max.apply(null, points)
      min = Math.min.apply(null, points)
      ret = if type == globals.REGRESSION.LOGARITHMIC
        if globals.curVis.canvas == 'timeline_canvas'
          points.map((y) -> (y - min) / (max - min))
        else
          points
      else
        console.log points.map((y) -> ((y - min) / (max - min)) + 1)
        points.map((y) -> ((y - min) / (max - min)) + 1)
    
    # Calculate the standard deviation
    calculateStandardDev = (points, mean) ->
      sigma = 0
      for point in points
        sigma += Math.pow(point - mean, 2)
      Math.sqrt( sigma / points.length )

    ###
    # Map the parameters of the learned feature space to the visualization space
    # (done by Gauss-Jordan elimination on a system of linear equations)
    ###
    visSpaceParameters = (Ps, xBounds, type) ->
      coeffMatrix = []
      solutionVector = []
      max = xBounds.dataMax
      min = xBounds.dataMin
      if globals.curVis.canvas == 'scatter_canvas' and type == globals.REGRESSION.LOGARITHMIC
        return Ps
      # for i in [0...Ps.length]
      #   xv = (i / Ps.length)
        
      #   # Calculate hypothesis of each input over the data range
      #   hypothesis = if type != globals.REGRESSION.LOGARITHMIC
      #     globals.REGRESSION.FUNCS[type][0](xv + 1, Ps)
      #   else
      #     if globals.curVis.canvas == 'scatter_canvas'
      #       globals.REGRESSION.FUNCS[type][0](xv * (max - min) + min, Ps)
      #     else
      #       globals.REGRESSION.FUNCS[type][0](xv, Ps)
      newPs = []  
      switch type
        when globals.REGRESSION.LINEAR
          coeffMatrix.push [1, min]
          coeffMatrix.push [1, max]
          solutionVector.push globals.REGRESSION.FUNCS[globals.REGRESSION.LINEAR][0](1, Ps)
          solutionVector.push globals.REGRESSION.FUNCS[globals.REGRESSION.LINEAR][0](2, Ps)
          newPs = numeric.solve(coeffMatrix, solutionVector)
        when globals.REGRESSION.QUADRATIC
          coeffMatrix.push [1, min, min * min]
          coeffMatrix.push [1, (max + min) / 2, ((max + min) / 2) * ((max + min) / 2)]
          coeffMatrix.push [1, max, max * max]
          solutionVector.push globals.REGRESSION.FUNCS[globals.REGRESSION.QUADRATIC][0](1, Ps)
          solutionVector.push globals.REGRESSION.FUNCS[globals.REGRESSION.QUADRATIC][0](1.5, Ps)
          solutionVector.push globals.REGRESSION.FUNCS[globals.REGRESSION.QUADRATIC][0](2, Ps)
          newPs = numeric.solve(coeffMatrix, solutionVector)
        when globals.REGRESSION.CUBIC
          projection = 2 * (max - min) + min
          coeffMatrix.push [1, min, min * min, min * min * min]
          coeffMatrix.push [1, (max + min) / 2, Math.pow((max + min) / 2, 2), Math.pow((max + min) / 2, 3)]
          coeffMatrix.push [1, max, max * max, max * max * max]
          coeffMatrix.push [1, projection, projection * projection, projection * projection * projection]
          solutionVector.push globals.REGRESSION.FUNCS[globals.REGRESSION.CUBIC][0](1, Ps)
          solutionVector.push globals.REGRESSION.FUNCS[globals.REGRESSION.CUBIC][0](1.5, Ps)
          solutionVector.push globals.REGRESSION.FUNCS[globals.REGRESSION.CUBIC][0](2, Ps)
          solutionVector.push globals.REGRESSION.FUNCS[globals.REGRESSION.CUBIC][0](3, Ps)
          console.log "coeffMatrix is #{coeffMatrix}"
          console.log "solutionVector is #{solutionVector}"
          newPs = numeric.solve(coeffMatrix, solutionVector)
        when globals.REGRESSION.EXPONENTIAL
          x = (xv + 1) * (max - min) + min
          coeffMatrix.push [x, 1]
          solutionVector.push Math.log(hypothesis - Ps[0])
        when globals.REGRESSION.LOGARITHMIC
          x = xv * (max - min) + min
          coeffMatrix.push [x, 1]
          solutionVector.push Math.exp(hypothesis - Ps[0])
      #newPs = numeric.solve(coeffMatrix, solutionVector)
      #console.log normalizeData([(max + min) / 4],3)
      newPs
      # PPrimes = Ps
      # P = []
      # max = xBounds.dataMax
      # min = xBounds.dataMin
      # switch type

      #   when globals.REGRESSION.LINEAR
      #     nx1 = 0
      #     nx2 = 1

      #     P[0] = 0
      #     P[1] = PPrimes[1] / (max - min)
        
      #   when globals.REGRESSION.QUADRATIC
      #     [1,1,1]
        
      #   when globals.REGRESSION.CUBIC
      #     [1,1,1,1]
        
      #   when globals.REGRESSION.EXPONENTIAL
      #     [1,1,1]
        
      #   when globals.REGRESSION.LOGARITHMIC
      #     #The hard case
      #     [1,1,1]
      # P