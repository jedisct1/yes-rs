use proc_macro::TokenStream;
use quote::quote;
use syn::{Item, ItemEnum, ItemFn, ItemImpl, ItemStruct, ItemTrait, parse_macro_input};

#[proc_macro_attribute]
pub fn noble(_args: TokenStream, input: TokenStream) -> TokenStream {
    let item = parse_macro_input!(input as Item);

    match item {
        Item::Fn(func) => wrap_function(func),
        Item::Struct(struct_item) => wrap_struct(struct_item),
        Item::Impl(impl_item) => wrap_impl(impl_item),
        Item::Enum(enum_item) => wrap_enum(enum_item),
        Item::Trait(trait_item) => wrap_trait(trait_item),
        _ => {
            // For unsupported items, just return them as-is
            quote! { #item }.into()
        }
    }
}

fn wrap_function(mut func: ItemFn) -> TokenStream {
    let original_block = &func.block;

    func.block = syn::parse_quote! {
        {
            unsafe #original_block
        }
    };

    quote! { #func }.into()
}

fn wrap_struct(struct_item: ItemStruct) -> TokenStream {
    let name = &struct_item.ident;
    let vis = &struct_item.vis;
    let attrs = &struct_item.attrs;
    let generics = &struct_item.generics;
    let (impl_generics, ty_generics, where_clause) = generics.split_for_impl();

    let original_struct = quote! {
        #(#attrs)*
        #vis struct #name #generics #struct_item.fields #where_clause
    };

    let constructor = match &struct_item.fields {
        syn::Fields::Named(fields) => {
            let field_names: Vec<_> = fields.named.iter().map(|f| &f.ident).collect();
            let field_types: Vec<_> = fields.named.iter().map(|f| &f.ty).collect();

            quote! {
                impl #impl_generics #name #ty_generics #where_clause {
                    pub unsafe fn new_unsafe(#(#field_names: #field_types),*) -> Self {
                        unsafe {
                            Self {
                                #(#field_names),*
                            }
                        }
                    }
                }
            }
        }
        syn::Fields::Unnamed(fields) => {
            let field_types: Vec<_> = fields.unnamed.iter().map(|f| &f.ty).collect();
            // let field_indices: Vec<_> = (0..field_types.len()).map(syn::Index::from).collect();
            let param_names: Vec<_> = (0..field_types.len())
                .map(|i| syn::Ident::new(&format!("field_{}", i), proc_macro2::Span::call_site()))
                .collect();

            quote! {
                impl #impl_generics #name #ty_generics #where_clause {
                    pub unsafe fn new_unsafe(#(#param_names: #field_types),*) -> Self {
                        unsafe {
                            Self(#(#param_names),*)
                        }
                    }
                }
            }
        }
        syn::Fields::Unit => {
            quote! {
                impl #impl_generics #name #ty_generics #where_clause {
                    pub unsafe fn new_unsafe() -> Self {
                        unsafe { Self }
                    }
                }
            }
        }
    };

    quote! {
        #original_struct
        #constructor
    }
    .into()
}

fn wrap_impl(mut impl_item: ItemImpl) -> TokenStream {
    // Check if this is a trait implementation (impl Trait for Type)
    if impl_item.trait_.is_some() {
        impl_item.unsafety = Some(syn::token::Unsafe::default());

        for item in &mut impl_item.items {
            if let syn::ImplItem::Fn(method) = item {
                let original_block = &method.block;
                method.block = syn::parse_quote! {
                    {
                        unsafe #original_block
                    }
                };
            }
        }
    } else {
        for item in &mut impl_item.items {
            if let syn::ImplItem::Fn(method) = item {
                let original_block = &method.block;
                method.block = syn::parse_quote! {
                    {
                        unsafe #original_block
                    }
                };
            }
        }
    }

    quote! { #impl_item }.into()
}

fn wrap_enum(enum_item: ItemEnum) -> TokenStream {
    let name = &enum_item.ident;
    let vis = &enum_item.vis;
    let attrs = &enum_item.attrs;
    let generics = &enum_item.generics;
    let (impl_generics, ty_generics, where_clause) = generics.split_for_impl();

    let variants = &enum_item.variants;
    let original_enum = quote! {
        #(#attrs)*
        #vis enum #name #generics #where_clause {
            #variants
        }
    };

    let variant_constructors: Vec<_> = enum_item
        .variants
        .iter()
        .map(|variant| {
            let variant_name = &variant.ident;
            let method_name = syn::Ident::new(
                &format!("new_{}_unsafe", variant_name.to_string().to_lowercase()),
                proc_macro2::Span::call_site(),
            );

            match &variant.fields {
                syn::Fields::Named(fields) => {
                    let field_names: Vec<_> = fields.named.iter().map(|f| &f.ident).collect();
                    let field_types: Vec<_> = fields.named.iter().map(|f| &f.ty).collect();
                    quote! {
                        pub unsafe fn #method_name(#(#field_names: #field_types),*) -> Self {
                            Self::#variant_name { #(#field_names),* }
                        }
                    }
                }
                syn::Fields::Unnamed(fields) => {
                    let field_types: Vec<_> = fields.unnamed.iter().map(|f| &f.ty).collect();
                    let param_names: Vec<_> = (0..field_types.len())
                        .map(|i| {
                            syn::Ident::new(&format!("field_{}", i), proc_macro2::Span::call_site())
                        })
                        .collect();
                    quote! {
                        pub unsafe fn #method_name(#(#param_names: #field_types),*) -> Self {
                            Self::#variant_name(#(#param_names),*)
                        }
                    }
                }
                syn::Fields::Unit => {
                    quote! {
                        pub unsafe fn #method_name() -> Self {
                            Self::#variant_name
                        }
                    }
                }
            }
        })
        .collect();

    quote! {
        #original_enum

        impl #impl_generics #name #ty_generics #where_clause {
            #(#variant_constructors)*
        }
    }
    .into()
}

fn wrap_trait(mut trait_item: ItemTrait) -> TokenStream {
    for item in &mut trait_item.items {
        if let syn::TraitItem::Fn(method) = item {
            method.sig.unsafety = Some(syn::token::Unsafe::default());

            if let Some(block) = &method.default {
                let original_block = block;
                method.default = Some(syn::parse_quote! {
                    {
                        unsafe #original_block
                    }
                });
            }
        }
    }

    trait_item.unsafety = Some(syn::token::Unsafe::default());

    quote! { #trait_item }.into()
}
