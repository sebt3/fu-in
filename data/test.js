widget		= { }
widget.base	= dgc.core.base;
widget.assert	= function() {
	var assert = widget.base();
/*	assert.dispatch.on("init.assert", function() {
		console.log('widget.assert init');
	});
	assert.dispatch.on("dataUpdate.assert", function() {
		console.log('widget.assert data');
	});*/
	assert.dispatch.on("renderUpdate.assert", function() {
		assert.root()
			.classed('assert-ok', assert.data().result==0)
			.classed('assert-failed', assert.data().result!=0)
			.text(assert.data().description)
			.append('span').classed('assert-cmd',true).classed('pull-right',true).text(assert.data().command+' ==> '+assert.data().result);
		/*console.log(assert.data().command)*/
	});
	
	return assert;
}
var stepCtn=0, testCnt=0;
widget.step	= function() {
	var step = widget.base(), id='step-'+(++stepCtn), id_infos='infos-'+stepCtn, icon;
	step.dispatch.on("renderUpdate.step", function() {
		var cl = step.data().assertFail>0?"panel-danger":"panel-success";
		step.root().call(bs.panel().title('<i class="fa fa-terminal" aria-hidden="true"></i>  '+step.data().name+' : '+step.data().description).class(cl));
		step.root().select('.panel').attr('id', 'step-'+step.data().name);
		icon = step.root().select('.panel-heading')
			.append('span').attr('class', 'pull-right  btn-panel-top')
			.append('button').attr('type', 'button').attr('class','btn').attr('data-widget','collapse').attr('data-target','#'+id).on('click.bs.collapse.data-api',	bs.api.collapse.click)
			.append('i').attr('class', (step.data().assertFail>0)?'fa fa-minus':'fa fa-plus');
		var root = step.root().select('.panel-body')
			.classed('collapse', true).classed('in', step.data().assertFail>0).attr('id',id)
			.on('shown.bs.collapse',		function(){icon.attr('class','fa fa-minus')})
			.on('hidden.bs.collapse',		function(){icon.attr('class','fa fa-plus')});
		var cmd = root.append('div').classed('step-cmd', true).text(step.data().command);
		var infos = root.append('div').attr('class', 'step-infos collapse').attr('id',id_infos);
		infos.append('div').classed('step-ret', true).text(step.data().return);
		if (step.data().stdout.length>0)
			infos.append('div').classed('step-out', true).text(step.data().stdout);
		if (step.data().stderr.length>0)
			infos.append('div').classed('step-err', true).text(step.data().stderr);
		var	update	= root.selectAll('div.assert').data(step.data().asserts);
		cmd.attr('data-widget','collapse').attr('data-target','#'+id_infos).on('click.bs.collapse.data-api',	bs.api.collapse.click);
		update.exit().remove();
		update.enter().append('div').attr('class','assert').each(function(d){d3.select(this).call(widget.assert().data(d))});
	});
	
	return step;
}
widget.test	= function() {
	var test = widget.base(), id="test-"+(++testCnt), icon;
	test.dispatch.on("renderUpdate.test", function() {
		var cl = test.data().result>0?"panel-danger":"panel-success";
		test.root().call(bs.panel().title('<i class="fa fa-list-ul" aria-hidden="true"></i> '+test.data().name+' : '+test.data().description).class(cl));
		test.root().select('.panel').attr('id', 'test-'+test.data().name);
		icon = test.root().select('.panel-heading')
			.append('span').attr('class', 'pull-right  btn-panel-top')
			.append('button').attr('type', 'button').attr('class','btn').attr('data-widget','collapse').attr('data-target','#'+id).on('click.bs.collapse.data-api',	bs.api.collapse.click)
			.append('i').attr('class', (test.data().result>0)?'fa fa-minus':'fa fa-plus');
		var root 	= test.root().select('.panel-body')
			.classed('collapse', true).classed('in', test.data().result>0).attr('id',id)
			.on('shown.bs.collapse',		function(){icon.attr('class','fa fa-minus')})
			.on('hidden.bs.collapse',		function(){icon.attr('class','fa fa-plus')})
		var update	= root.selectAll('div.step').data(test.data().steps);
		update.exit().remove();
		update.enter().append('div').attr('class','step').each(function(d){d3.select(this).call(widget.step().data(d))});
	});
	
	return test;
}
widget.group	= function() {
	var group = widget.base();
	group.dispatch.on("renderUpdate.group", function() {
		group.root().append('h3').html('<i class="fa fa-object-group" aria-hidden="true"></i> '+group.data().name).attr('id', 'group-'+group.data().name);
		var	update	= group.root().selectAll('div.test').data(group.data().tests);
		update.exit().remove();
		update.enter().append('div').attr('class','test').each(function(d){d3.select(this).call(widget.test().data(d))});
	});
	
	return group;
}
widget.report	= function() {
	var report = widget.base();
	var grp = { "cnt":0,"fail":0,"pct":10 }
	var tst = { "cnt":0,"fail":0,"pct":20 }
	var step = { "cnt":0,"fail":0,"pct":30 }
	var assert = { "cnt":0,"fail":0,"pct":40 }
	var overall = [], failed, bars = dgc.bar.bar();
	bars.bars().colorFunction = function(d) { if (d.key=="failed") return function(){return "#d9534f";}; else return function(){return "#5cb85c"; };}
	bars.bars().dispatch.on("click.bars", function(d) {window.location.href =d.data.url})
	bars.axes().xAxisLine		= function(g) {
		g.call(d3.axisBottom(bars.axes().xAxis));
		g.select(".domain").remove();
		g.selectAll(".tick line").attr("stroke", "none").style("stroke-width", "0px");
	}
	bars.axes().yAxisLine		= function(g) {
		g.call(d3.axisRight(bars.axes().yAxis).tickSize(bars.axes().width()));
		g.select(".domain").remove();
		g.selectAll(".tick line").attr("stroke", "lightgrey").style("stroke-width", "0px");
		g.selectAll(".tick:not(:first-of-type) line").attr("stroke-dasharray", "5,5");
		g.selectAll(".tick text").attr("x", -20);
	};
	report.dispatch.on("dataUpdate.report", function() {
		grp.cnt = report.data().groups.length;
		var g, t, s;
		for(g=0;g<grp.cnt;g++) {
			if (report.data().groups[g].result>0)
				grp.fail++;
			tst.cnt += report.data().groups[g].tests.length;
			for(t=0;t<report.data().groups[g].tests.length;t++) {
				failed=0;
				if (report.data().groups[g].tests[t].result>0)
					tst.fail++;
				step.cnt += report.data().groups[g].tests[t].steps.length;
				for (s=0;s<report.data().groups[g].tests[t].steps.length;s++) {
					if (report.data().groups[g].tests[t].steps[s].assertFail>0) {
						step.fail++;
						failed++;
					}
					assert.cnt  += report.data().groups[g].tests[t].steps[s].assertCnt;
					assert.fail += report.data().groups[g].tests[t].steps[s].assertFail;
				}
				overall.push({
					"type":report.data().groups[g].tests[t].name,
					"url":"#test-"+report.data().groups[g].tests[t].name,
					"sucess": report.data().groups[g].tests[t].steps.length - failed,
					"failed": failed
				});
			}
		}
		grp.pct = (grp.cnt-grp.fail)*100/grp.cnt;
		tst.pct = (tst.cnt-tst.fail)*100/tst.cnt;
		step.pct = (step.cnt-step.fail)*100/step.cnt;
		assert.pct = (assert.cnt-assert.fail)*100/assert.cnt;
		bars.data(overall);
	});
	report.dispatch.on("renderUpdate.report", function() {
		var g, t, p;
		var row = report.root().append('div').attr('id','summary').append('div').classed('row',true);
		var bar = row.append('div').attr('class','col-md-12').call(bs.panel().class('panel-info').title('<i class="fa fa-bar-chart" aria-hidden="true"></i> Overall'));
		bar.select('.panel-body').append('div').call(bars);
		var st = row.append('div').attr('class','col-md-6').call(bs.panel().class('panel-info').title('<i class="fa fa-pie-chart" aria-hidden="true"></i> Statistics'));
		st.select('.panel-body').append('div').call(bs.row()
			.cell('col-md-3',dgc.donut.donutWithLines()
				.line1('Groups').line2(dgc.core.format.fileSize(grp.pct)+'%')
				.data([ {"label":"failed", "value":grp.fail, "color":"#d9534f" },
					{"label":"succes", "value":grp.cnt-grp.fail, "color":"#5cb85c" }]))
			.cell('col-md-3',dgc.donut.donutWithLines()
				.line1('Tests').line2(dgc.core.format.fileSize(tst.pct)+'%')
				.data([ {"label":"failed", "value":tst.fail, "color":"#d9534f" },
					{"label":"succes", "value":tst.cnt-tst.fail, "color":"#5cb85c" }]))
			.cell('col-md-3',dgc.donut.donutWithLines()
				.line1('Steps').line2(dgc.core.format.fileSize(step.pct)+'%')
				.data([ {"label":"failed", "value":step.fail, "color":"#d9534f" },
					{"label":"succes", "value":step.cnt-step.fail, "color":"#5cb85c" }]))
			.cell('col-md-3',dgc.donut.donutWithLines()
				.line1('Asserts').line2(dgc.core.format.fileSize(assert.pct)+'%')
				.data([ {"label":"failed", "value":assert.fail, "color":"#d9534f" },
					{"label":"succes", "value":assert.cnt-assert.fail, "color":"#5cb85c" }])));
		var fail = row.append('div').attr('class','col-md-6').call(bs.panel().class('panel-danger').title('<i class="fa fa-exclamation-circle" aria-hidden="true"></i> Failed tests list'));
		for(g=0;g<grp.cnt;g++) {
			for(t=0;t<report.data().groups[g].tests.length;t++) {
				if (report.data().groups[g].tests[t].result>0) {
					p = (report.data().groups[g].tests[t].total-report.data().groups[g].tests[t].result)*100/report.data().groups[g].tests[t].total;
					fail.select('.panel-body').append('div').call(bs.progress()
						.url('#test-'+report.data().groups[g].tests[t].name)
						.title(report.data().groups[g].tests[t].description)
						.data([{'pct': p, 'class':'progress-bar-success'}]))
						.select('.progress').classed('progress-bar-danger',true);
				}
			}
		}
		var	update	= report.root().selectAll('div.group').data(report.data().groups);
		update.exit().remove();
		update.enter().append('div').attr('class','group').each(function(d){d3.select(this).call(widget.group().data(d))});
		//console.log(report.data());
	});
	return report;
}
widget.toc	= function() {
	var toc = widget.base();
	toc.dispatch.on("renderUpdate.toc", function() {
		var ul=toc.root().append('ul').attr('id','nav').attr('class','nav hidden-xs hidden-sm').attr('data-spy','affix');
		var update = ul.selectAll('li').data(toc.data().groups);
		update.exit().remove();
		ul.append('li').append('a').attr('href','#summary').html('<i class="fa fa-pie-chart" aria-hidden="true"></i> Summary')
		update.enter().append('li').each(function(d){
			d3.select(this).append('a').attr('href','#group-'+d.name).html('<i class="fa fa-object-group" aria-hidden="true"></i> '+d.name);
			if(d.tests.length>0) {
				d3.select(this).append('ul').attr('class','nav').selectAll('li')
					.data(d.tests).enter().append('li').each(function(d){
					d3.select(this).append('a')
						.attr('href','#test-'+d.name)
						.html('<i class="fa fa-list-ul" aria-hidden="true"></i> '+d.name);
					if(d.steps.length>0) {
						d3.select(this).append('ul').attr('class','nav')
							.selectAll('li').data(d.steps)
							.enter().append('li').each(function(d){
							d3.select(this).append('a')
								.attr('href','#step-'+d.name)
								.html('<i class="fa fa-terminal" aria-hidden="true"></i> '+d.name);
						});
					}
				});
			}
		});
		ul.each(bs.api.affix.init);
		d3.select('body').attr('data-spy','scroll').attr('data-target','.scrollspy').each(bs.api.scroll.init);
	});
	return toc;
}
