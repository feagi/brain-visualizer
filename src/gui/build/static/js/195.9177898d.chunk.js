"use strict";(self.webpackChunkfeagi_ui=self.webpackChunkfeagi_ui||[]).push([[195],{6394:function(e,n,i){i.d(n,{n:function(){return t}});var t={version:"2.0",max_burst_count:3,burst_delay:.1,evolution_burst_count:50,ipu_idle_threshold:1e3,neuron_morphologies:{block_to_block:{vectors:[[0,0,0]]},decrease_filter_diagonal:{vectors:[[0,1,1]]},decrease_filter_diagonal2:{vectors:[[0,2,1]]},increase_filter_diagonal:{vectors:[[0,1,-1]]},increase_filter_diagonal2:{vectors:[[0,2,-1]]},y_consolidator:{patterns:[["*","*","*"],["*","?","*"]]},"lateral_+x":{vectors:[[1,0,0]]},"lateral_-x":{vectors:[[-1,0,0]]},"lateral_+y":{vectors:[[0,1,0]]},"lateral_-y":{vectors:[[0,-1,0]]},"lateral_+z":{vectors:[[0,0,1]]},"lateral_-z":{vectors:[[0,0,-1]]},one_to_all:{patterns:[[1,1,1],["*","*","*"]]},all_to_one:{patterns:[["*","*","*"],[1,1,1]]},"to_block_[5, 7, 4]":{patterns:[["*","*","*"],[5,7,4]]},expander_x:{functions:!0},reducer_x:{functions:!0},randomizer:{functions:!0},lateral_pairs_x:{functions:!0}},species:{parents:{},species_id:"",class:"toy",brand:"gazebo",model:"smart_car"},blueprint:{}}},7195:function(e,n,i){i.r(n),i.d(n,{default:function(){return Q}});var t=i(7762),r=i(5861),a=i(1413),s=i(2982),l=i(885),c=i(7757),d=i.n(c),o=i(2791),x=i(6871),u=i(2419),f=i(7394),p=i(8264),h=i(6151),Z=i(9823),j=i(7247),m=i(5289),b=i(7123),g=i(9157),v=i(3518),y=i(1286),_=i(9877),A=i(9353),w=i.n(A),C=i(3400),k=i(4925),I=i(703),P=i(3767),S=i(7630),z=i(9836),O=i(3382),D=i(3994),G=i(9281),M=i(6890),E=i(6812),F=i(5855),W=i(9013),X=i(8550),Y=i(890),B=i(4942),L=i(4721),N=i(3329),V=i(1469),J=i(184),K=function(e){var n=(0,o.useState)(e.corticalArea),i=(0,l.Z)(n,2),t=i[0],r=i[1],s=(0,o.useState)(""),c=(0,l.Z)(s,2),d=c[0],x=c[1],u=(0,o.useState)(""),f=(0,l.Z)(u,2),p=f[0],h=f[1],Z=(0,o.useState)(""),j=(0,l.Z)(Z,2),m=j[0],b=j[1],g=(0,o.useState)(""),v=(0,l.Z)(g,2),y=v[0],A=v[1],w=(0,o.useState)(""),C=(0,l.Z)(w,2),I=C[0],S=C[1],z=(0,o.useState)(""),O=(0,l.Z)(z,2),D=O[0],G=O[1],M=(0,o.useState)(""),E=(0,l.Z)(M,2),F=E[0],W=E[1],K={};Object.keys(e.defaultCorticalGenes).forEach((function(n){K[e.defaultCorticalGenes[n][0]]=e.defaultCorticalGenes[n][1]}));return(0,J.jsxs)(J.Fragment,{children:[(0,J.jsxs)(Y.Z,{gutterBottom:!0,variant:"h5",component:"div",sx:{mb:1},children:[e.corticalArea," cortical area properties"]}),(0,J.jsx)(L.Z,{sx:{mb:2}}),(0,J.jsxs)(P.Z,{direction:"row",alignItems:"center",spacing:2,sx:{m:1},children:[(0,J.jsx)(k.Z,{sx:{width:"80px"},children:"Label"}),(0,J.jsx)(X.Z,{id:"filled-basic-label",label:"cortical area name...",defaultValue:e.corticalArea,variant:"filled",onChange:function(e){return r(e.target.value)},sx:{width:"330px"}})]}),(0,J.jsxs)(P.Z,{direction:"row",alignItems:"center",spacing:2,sx:{m:1},children:[(0,J.jsx)(k.Z,{sx:{width:"80px"},children:"Group ID"}),(0,J.jsx)(X.Z,{id:"filled-basic-group-id",label:"6 char max",variant:"filled",onChange:function(e){return x(e.target.value)},sx:{width:"330px"},inputProps:{maxLength:6}})]}),(0,J.jsxs)(P.Z,{direction:"row",alignItems:"center",spacing:2,sx:{m:1},children:[(0,J.jsx)(k.Z,{sx:{width:"80px"},children:"Position"}),(0,J.jsx)(X.Z,{id:"filled-basic-px",label:"X",variant:"filled",onChange:function(e){return h(e.target.value)},sx:{width:"100px"}}),(0,J.jsx)(X.Z,{id:"filled-basic-py",label:"Y",variant:"filled",onChange:function(e){return b(e.target.value)},sx:{width:"100px"}}),(0,J.jsx)(X.Z,{id:"filled-basic-pz",label:"Z",variant:"filled",onChange:function(e){return A(e.target.value)},sx:{width:"100px"}})]}),(0,J.jsxs)(P.Z,{direction:"row",alignItems:"center",spacing:2,sx:{m:1},children:[(0,J.jsx)(k.Z,{sx:{width:"80px"},children:"Dimension"}),(0,J.jsx)(X.Z,{id:"filled-basic-dx",label:"X",variant:"filled",onChange:function(e){return S(e.target.value)},sx:{width:"100px"}}),(0,J.jsx)(X.Z,{id:"filled-basic-dy",label:"Y",variant:"filled",onChange:function(e){return G(e.target.value)},sx:{width:"100px"}}),(0,J.jsx)(X.Z,{id:"filled-basic-dz",label:"Z",variant:"filled",onChange:function(e){return W(e.target.value)},sx:{width:"100px"}})]}),(0,J.jsx)(Y.Z,{gutterBottom:!0,variant:"h6",component:"div",sx:{justifyContent:"center",mt:4,mb:1},children:"Neuron Parameters (advanced options)"}),(0,J.jsx)(L.Z,{sx:{mb:2}}),Object.keys(e.defaultCorticalGenes).map((function(n,i){return(0,J.jsxs)(P.Z,{direction:"row",alignItems:"center",spacing:2,sx:{m:1},children:[(0,J.jsx)(k.Z,{sx:{width:"250px"},children:n},"input-".concat(i)),(0,J.jsx)(X.Z,{id:"filled-basic-".concat(i),label:e.defaultCorticalGenes[n][0],defaultValue:e.defaultCorticalGenes[n][1],variant:"filled",onChange:function(i){return t=i.target.value,r=e.defaultCorticalGenes[n][0],void(K[r]=t);var t,r},sx:{width:"150px"}},"field-".concat(i))]},"stack-".concat(i))})),(0,J.jsx)(P.Z,{direction:"row",alignItems:"center",justifyContent:"center",spacing:2,sx:{m:2},children:(0,J.jsx)(V.Z,{title:"Save",children:(0,J.jsx)("span",{children:(0,J.jsx)(_.Z,{size:"large",color:"primary","aria-label":"add",sx:{m:1},disabled:!(t&&p&&m&&y&&I&&D&&F),onClick:function(){var n=function(){var e,n="_____10c-".concat(d,"-"),i=n.concat("cx-__name-t"),r=n.concat("nx-rcordx-i"),s=n.concat("nx-rcordy-i"),l=n.concat("nx-rcordz-i"),c=n.concat("nx-___bbx-i"),o=n.concat("nx-___bby-i"),x=n.concat("nx-___bbz-i"),u=n.concat("cx-dstmap-d"),f={};return Object.keys(K).forEach((function(e){f[n.concat(e)]=K[e]})),(0,a.Z)((e={},(0,B.Z)(e,i,t),(0,B.Z)(e,r,parseInt(p)),(0,B.Z)(e,s,parseInt(m)),(0,B.Z)(e,l,parseInt(y)),(0,B.Z)(e,c,parseInt(I)),(0,B.Z)(e,o,parseInt(D)),(0,B.Z)(e,x,parseInt(F)),(0,B.Z)(e,u,{}),e),f)}();e.setDefinedAreas((0,a.Z)((0,a.Z)({},e.definedAreas),{},(0,B.Z)({},e.corticalArea,n))),e.setDialogOpen(!1)},children:(0,J.jsx)(N.Z,{})})})})})]})},R=i(6394),q=i(9489),H=(0,S.ZP)("input")({display:"none"}),Q=function(e){var n=(0,o.useState)([].concat((0,s.Z)(e.selectedSensory),(0,s.Z)(e.selectedMotor),(0,s.Z)(e.customAreas))),i=(0,l.Z)(n,2),c=i[0],A=i[1],S=(0,o.useState)(!1),B=(0,l.Z)(S,2),L=B[0],N=B[1],V=(0,o.useState)(""),Q=(0,l.Z)(V,2),T=Q[0],U=Q[1],$=(0,o.useState)(10),ee=(0,l.Z)($,2),ne=ee[0],ie=ee[1],te=(0,o.useState)(0),re=(0,l.Z)(te,2),ae=re[0],se=re[1],le=(0,o.useState)(""),ce=(0,l.Z)(le,2),de=ce[0],oe=ce[1],xe=(0,o.useState)(!1),ue=(0,l.Z)(xe,2),fe=ue[0],pe=ue[1],he=function(){N(!1)},Ze=(0,x.s0)(),je=function(){A([].concat((0,s.Z)(c),[de])),e.setCustomAreas([].concat((0,s.Z)(e.customAreas),[de])),pe(!1)},me=function(){pe(!1)},be=function(){var n=(0,r.Z)(d().mark((function n(i){var r,a,s,l,c,o,x,u,f;return d().wrap((function(n){for(;;)switch(n.prev=n.next){case 0:return n.next=2,q.Z.postGenomeFileEdit({file:i.target.files[0]});case 2:r=n.sent,a=r.blueprint,s={},l={},c=Object.entries(a).filter((function(e){return e[0].includes("name-")})),o=(0,t.Z)(c);try{for(o.s();!(x=o.n()).done;)u=x.value,s[a[u[0]]]={},l[u[0].slice(9,15)]=u[1]}catch(d){o.e(d)}finally{o.f()}for(f in a)s[l[f.slice(9,15)]][f]=a[f];A(Object.keys(s)),e.setDefinedAreas(s);case 12:case"end":return n.stop()}}),n)})));return function(e){return n.apply(this,arguments)}}();return(0,J.jsxs)(J.Fragment,{children:[(0,J.jsx)(Y.Z,{variant:"h4",component:"div",sx:{mt:4,ml:4,mb:1},children:"Define/Edit Cortical Areas"}),(0,J.jsxs)(G.Z,{component:I.Z,sx:{mt:"20px"},children:[(0,J.jsxs)(z.Z,{children:[(0,J.jsx)(M.Z,{sx:{backgroundColor:"lightgray"},children:(0,J.jsxs)(F.Z,{children:[(0,J.jsx)(D.Z,{align:"center",children:(0,J.jsx)(Y.Z,{variant:"h5",children:"Area"})}),(0,J.jsx)(D.Z,{align:"left",children:(0,J.jsx)(Y.Z,{variant:"h5",children:"Dimensions"})}),(0,J.jsx)(D.Z,{align:"left",children:(0,J.jsx)(Y.Z,{variant:"h5",children:"Position"})}),(0,J.jsx)(D.Z,{align:"center",children:(0,J.jsx)(Y.Z,{variant:"h5",children:"Management"})})]})}),(0,J.jsx)(O.Z,{children:c.slice(ae*ne,ae*ne+ne).map((function(n,i){return(0,J.jsxs)(F.Z,{hover:!0,children:[(0,J.jsx)(D.Z,{align:"center",component:"th",scope:"row",style:{width:"400px"},children:(0,J.jsx)(Y.Z,{children:n})}),(0,J.jsx)(D.Z,{style:{width:"500px"},children:(0,J.jsxs)(P.Z,{direction:"row",alignItems:"center",spacing:2,children:[(0,J.jsx)(X.Z,{id:"filled-basic-dx",label:"X",variant:"filled",disabled:!0,value:n in e.definedAreas?e.definedAreas[n][Object.keys(e.definedAreas[n]).filter((function(e){return e.includes("bbx")}))[0]]:"none",sx:{width:"75px"},InputProps:{inputProps:{style:{textAlign:"center"}}}}),(0,J.jsx)(X.Z,{id:"filled-basic-dy",label:"Y",variant:"filled",disabled:!0,value:n in e.definedAreas?e.definedAreas[n][Object.keys(e.definedAreas[n]).filter((function(e){return e.includes("bby")}))[0]]:"none",sx:{width:"75px"},InputProps:{inputProps:{style:{textAlign:"center"}}}}),(0,J.jsx)(X.Z,{id:"filled-basic-dz",label:"Z",variant:"filled",disabled:!0,value:n in e.definedAreas?e.definedAreas[n][Object.keys(e.definedAreas[n]).filter((function(e){return e.includes("bbz")}))[0]]:"none",sx:{width:"75px"},InputProps:{inputProps:{style:{textAlign:"center"}}}})]})}),(0,J.jsx)(D.Z,{align:"center",style:{width:"400px"},children:(0,J.jsxs)(P.Z,{direction:"row",alignItems:"center",spacing:2,children:[(0,J.jsx)(X.Z,{id:"filled-basic-px",label:"X",variant:"filled",disabled:!0,value:n in e.definedAreas?e.definedAreas[n][Object.keys(e.definedAreas[n]).filter((function(e){return e.includes("rcordx")}))[0]]:"none",sx:{width:"75px"},InputProps:{inputProps:{style:{textAlign:"center"}}}}),(0,J.jsx)(X.Z,{id:"filled-basic-py",label:"Y",variant:"filled",disabled:!0,value:n in e.definedAreas?e.definedAreas[n][Object.keys(e.definedAreas[n]).filter((function(e){return e.includes("rcordy")}))[0]]:"none",sx:{width:"75px"},InputProps:{inputProps:{style:{textAlign:"center"}}}}),(0,J.jsx)(X.Z,{id:"filled-basic-pz",label:"Z",variant:"filled",disabled:!0,value:n in e.definedAreas?e.definedAreas[n][Object.keys(e.definedAreas[n]).filter((function(e){return e.includes("rcordz")}))[0]]:"none",sx:{width:"75px"},InputProps:{inputProps:{style:{textAlign:"center"}}}})]})}),(0,J.jsx)(D.Z,{align:"center",children:(0,J.jsxs)(J.Fragment,{children:[(0,J.jsx)(_.Z,{size:"small",color:"primary","aria-label":"add-icon",sx:{m:2},onClick:function(){return function(e){U(e),N(!0)}(n)},children:(0,J.jsx)(y.Z,{})}),(0,J.jsx)(_.Z,{size:"small",color:"primary","aria-label":"delete-icon",sx:{m:2},onClick:function(){return function(n,i){var t=i+ae*ne,r=(0,s.Z)(c);if(r.splice(t,1),A(r),n in e.definedAreas){var l=(0,a.Z)({},e.definedAreas);delete l[n],e.setDefinedAreas(l)}}(n,i)},children:(0,J.jsx)(j.Z,{})})]})})]},i)}))})]}),(0,J.jsx)(_.Z,{size:"medium",color:"primary","aria-label":"add",sx:{mt:7,ml:2,mr:2,mb:2},onClick:function(){pe(!0)},children:(0,J.jsx)(u.Z,{})}),(0,J.jsx)(_.Z,{size:"medium",color:"primary","aria-label":"save",sx:{mt:7,ml:2,mr:2,mb:2},disabled:!e.definedAreas,onClick:function(){var n=R.n,i={};for(var t in e.definedAreas)for(var r in e.definedAreas[t])i[r]=e.definedAreas[t][r];n.blueprint=i;var a="genome_".concat(Date.now(),".json");w()(JSON.stringify(n),a)},children:(0,J.jsx)(v.Z,{})}),(0,J.jsxs)("label",{htmlFor:"genome-upload",children:[(0,J.jsx)(H,{id:"genome-upload",accept:".json",type:"file",onChange:be,onClick:function(e){e.target.value=""}}),(0,J.jsx)(_.Z,{id:"genome-upload",component:"span",size:"medium",color:"primary",sx:{mt:7,ml:2,mr:2,mb:2},children:(0,J.jsx)(W.Z,{})})]}),(0,J.jsx)(E.Z,{rowsPerPageOptions:[5,10,25,50,100],component:"div",count:c.length,rowsPerPage:parseInt(ne,10),page:ae,onPageChange:function(e,n){se(n)},onRowsPerPageChange:function(e){ie(parseInt(e.target.value,10)),se(0)}})]}),(0,J.jsxs)(P.Z,{direction:"row",alignItems:"center",justifyContent:"center",spacing:2,sx:{m:8},children:[(0,J.jsx)(_.Z,{size:"large",color:"primary","aria-label":"add",sx:{m:1},onClick:function(){Ze("/brain/sensorimotor")},children:(0,J.jsx)(f.Z,{})}),(0,J.jsx)(_.Z,{size:"large",color:"primary","aria-label":"add",sx:{m:1},disabled:Object.keys(e.definedAreas).length!==c.length,onClick:function(){Ze("/brain/mapping")},children:(0,J.jsx)(p.Z,{})})]}),L&&(0,J.jsx)(m.Z,{open:L,onClose:he,fullWidth:!0,maxWidth:"md",children:(0,J.jsx)(g.Z,{children:(0,J.jsx)(K,{setDialogOpen:N,definedSensory:e.definedSensory,setDefinedSensory:e.setDefinedSensory,definedMotor:e.definedMotor,setDefinedMotor:e.setDefinedMotor,definedAreas:e.definedAreas,setDefinedAreas:e.setDefinedAreas,defaultCorticalGenes:e.defaultCorticalGenes,corticalArea:T})})}),fe&&(0,J.jsx)(m.Z,{open:fe,fullWidth:!0,maxWidth:"sm",children:(0,J.jsxs)(g.Z,{children:[(0,J.jsx)("div",{style:{display:"flex",justifyContent:"flex-end"},children:(0,J.jsx)(C.Z,{sx:{mb:2},onClick:me,children:(0,J.jsx)(Z.Z,{})})}),(0,J.jsxs)(P.Z,{direction:"row",alignItems:"center",spacing:2,sx:{m:1},children:[(0,J.jsx)(k.Z,{sx:{width:"350px"},children:(0,J.jsxs)(Y.Z,{fontWeight:"bold",children:["Enter a name for the cortical area:"," "]})}),(0,J.jsx)(X.Z,{id:"filled-basic",variant:"filled",onChange:function(e){return oe(e.target.value)},sx:{width:"330px"}})]}),(0,J.jsx)(b.Z,{children:(0,J.jsx)(h.Z,{variant:"contained",onClick:je,disabled:!de,children:"OK"})})]})})]})}}}]);
//# sourceMappingURL=195.9177898d.chunk.js.map