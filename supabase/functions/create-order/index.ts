import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'

const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type"}
serve(async(req)=>{
  if(req.method==='OPTIONS') return new Response('ok',{headers:cors})
  try{
    const auth=req.headers.get('Authorization')||''
    const supabase=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:auth}}})
    const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
    const {data:{user}}=await supabase.auth.getUser(); if(!user) throw new Error('Unauthorized')
    const body=await req.json(); const {address_id,delivery_type,payment_method,items,coupon_code}=body
    if(!address_id||!Array.isArray(items)||items.length===0) throw new Error('Invalid checkout')
    const {data:address}=await admin.from('addresses').select('*').eq('id',address_id).eq('user_id',user.id).single(); if(!address) throw new Error('Address not found')
    const {data:inside}=await admin.rpc('validate_chandigarh_point',{lat:address.latitude,lng:address.longitude}); if(!inside) throw new Error('Sorry, FMLY CRAFT currently delivers only within Chandigarh.')
    const ids=items.map((x:any)=>x.product_id)
    const {data:products}=await admin.from('products').select('*').in('id',ids).eq('is_active',true)
    if(!products||products.length!==ids.length) throw new Error('One or more products are unavailable')
    let subtotal=0
    const lines=[]
    for(const item of items){const p=products.find((x:any)=>x.id===item.product_id); const q=Number(item.quantity); if(!p||!Number.isInteger(q)||q<1||q>p.stock_quantity) throw new Error(`Insufficient stock for ${p?.name||'product'}`); subtotal+=Number(p.price)*q; lines.push({product_id:p.id,product_name_snapshot:p.name,price_snapshot:p.price,quantity:q,subtotal:Number(p.price)*q})}
    const {data:settings}=await admin.from('delivery_settings').select('*').single();
    const delivery=delivery_type==='fast'?Number(settings?.normal_charge||20)+Number(settings?.fast_extra||10):delivery_type==='express'?Number(settings?.normal_charge||20)+Number(settings?.express_extra||20):Number(settings?.normal_charge||20)
    if(payment_method==='cod' && !settings?.cod_enabled) throw new Error('Cash on Delivery is disabled')
    if(payment_method==='cod' && subtotal+delivery<Number(settings?.cod_minimum||100)) throw new Error('COD is unavailable below the configured minimum amount')
    const orderNumber='#FC'+Math.floor(100000+Math.random()*899999)
    const total=subtotal+delivery
    const {data:order,error}=await admin.from('orders').insert({order_number:orderNumber,user_id:user.id,address_id,subtotal,delivery_charge:delivery,total,delivery_type,payment_method,payment_status:'pending',status:'pending'}).select().single(); if(error) throw error
    for(const line of lines){const ok=await admin.rpc('decrement_stock',{p_product:line.product_id,p_qty:line.quantity}); if(!ok.data) throw new Error(`Inventory changed for ${line.product_name_snapshot}; please retry`)}
    const {error:itemError}=await admin.from('order_items').insert(lines.map((x:any)=>({...x,order_id:order.id}))); if(itemError) throw itemError
    await admin.from('order_status_history').insert({order_id:order.id,actor_id:user.id,new_status:'pending'})
    return new Response(JSON.stringify({order_id:order.id,order_number:order.order_number,total}),{headers:{...cors,'Content-Type':'application/json'}})
  }catch(e){return new Response(JSON.stringify({error:String(e.message||e)}),{status:400,headers:{...cors,'Content-Type':'application/json'}})}
})
